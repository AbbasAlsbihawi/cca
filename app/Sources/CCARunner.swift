import Foundation

typealias CCAResult = (status: Int32, stdout: String, stderr: String)

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

enum CCARunner {
    static let notInstalled = "cca is not installed: run install.sh"
    static let marker = "@@CCA@@"

    static var home: String {
        let v = ProcessInfo.processInfo.environment["CCA_HOME"] ?? ""
        return v.isEmpty ? NSHomeDirectory() + "/.claude-accounts" : v
    }

    static var installed: Bool { FileManager.default.fileExists(atPath: home + "/cca.zsh") }

    private static let pathTask = Task.detached(priority: .utility) { computePath() }

    private static func computePath() -> String {
        let h = NSHomeDirectory()
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "CLAUDECODE")
        var parts = ["\(h)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"]
        let r = spawn("/bin/zsh", ["-l", "-c", "print -rn -- \"\(marker)$PATH\""], env: env, timeout: 3)
        if r.status == 0, let range = r.stdout.range(of: marker, options: .backwards) {
            parts += r.stdout[range.upperBound...].split(separator: ":").map(String.init)
        }
        parts += ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        var seen = Set<String>()
        return parts.filter { !$0.isEmpty && seen.insert($0).inserted }.joined(separator: ":")
    }

    static func path() async -> String { await pathTask.value }

    static func environment() async -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["CCA_HOME"] = home
        env.removeValue(forKey: "CLAUDECODE")
        if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }
        env["PATH"] = await path()
        return env
    }

    /// Runs a process to completion, draining both pipes concurrently.
    static func spawn(_ exe: String, _ args: [String], env: [String: String], timeout: TimeInterval?) -> CCAResult {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        p.environment = env
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = FileHandle.nullDevice
        do { try p.run() } catch { return (127, "", "could not start \(exe): \(error.localizedDescription)") }
        let timedOut = Box(false)
        let giveUp = Box(Date.distantFuture)
        var timer: DispatchWorkItem?
        if let t = timeout {
            let w = DispatchWorkItem {
                guard p.isRunning else { return }
                timedOut.value = true
                giveUp.value = Date().addingTimeInterval(5)
                p.terminate()
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) { if p.isRunning { kill(p.processIdentifier, SIGKILL) } }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + t, execute: w)
            timer = w
        }
        let group = DispatchGroup()
        let lock = NSLock()
        let outData = Box(Data()), errData = Box(Data())
        func drain(_ fh: FileHandle, into box: Box<Data>) {
            group.enter()
            DispatchQueue.global().async {
                while true {
                    let chunk = fh.availableData
                    if chunk.isEmpty { break }
                    lock.lock(); box.value.append(chunk); lock.unlock()
                }
                group.leave()
            }
        }
        drain(out.fileHandleForReading, into: outData)
        drain(err.fileHandleForReading, into: errData)
        // After a timeout a surviving grandchild can hold the pipes open; stop waiting for them then.
        while group.wait(timeout: .now() + 0.25) == .timedOut {
            if Date() > giveUp.value { break }
        }
        if !timedOut.value { p.waitUntilExit() }
        timer?.cancel()
        lock.lock()
        let outBytes = outData.value, errBytes = errData.value
        lock.unlock()
        var stderr = String(decoding: errBytes, as: UTF8.self)
        if timedOut.value { stderr += (stderr.isEmpty ? "" : "\n") + "timed out after \(Int(timeout ?? 0)) s" }
        return (timedOut.value ? -1 : p.terminationStatus, String(decoding: outBytes, as: UTF8.self), stderr)
    }

    static func run(_ args: [String], timeout: TimeInterval? = nil) async -> CCAResult {
        guard installed else { return (127, "", notInstalled) }
        let env = await environment()
        let argv = ["-f", "-c", "source \"$CCA_HOME/cca.zsh\" && cca \"$@\"", "cca"] + args
        return await withCheckedContinuation { c in
            DispatchQueue.global().async { c.resume(returning: spawn("/bin/zsh", argv, env: env, timeout: timeout)) }
        }
    }

    static func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Writes a self-deleting .command file with the given body lines and opens it in Terminal. Returns an error message or nil.
    static func terminal(_ lines: [String]) async -> String? {
        let path = await path()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cca-\(UUID().uuidString).command")
        let body = ["#!/bin/zsh -f", "rm -f -- \"$0\"", "unset CLAUDECODE", "export CCA_HOME=\(quote(home))", "export PATH=\(quote(path))"] + lines
        let made = FileManager.default.createFile(atPath: url.path, contents: Data((body.joined(separator: "\n") + "\n").utf8),
                                                  attributes: [.posixPermissions: 0o700])
        guard made else { return "could not write \(url.path)" }
        let r = await withCheckedContinuation { c in
            DispatchQueue.global().async {
                c.resume(returning: spawn("/usr/bin/open", ["-a", "Terminal", url.path], env: ProcessInfo.processInfo.environment, timeout: 15))
            }
        }
        if r.status != 0 {
            try? FileManager.default.removeItem(at: url)
            return "could not open Terminal: " + r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    /// Terminal script that runs one cca command and waits for a key.
    static func ccaLines(_ args: [String]) -> [String] {
        ["source \"$CCA_HOME/cca.zsh\"", "cca " + args.map(quote).joined(separator: " "), "read -k1 '?Press any key to close…'"]
    }

    static func newTerminalLines(_ name: String) -> [String] {
        ["print -r -- \(quote("This terminal now uses: \(name)  (cca use - to stop)"))",
         "export CCA_ACCOUNT=\(quote(name)); cd ~; exec /bin/zsh -il"]
    }
}
