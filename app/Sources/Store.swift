import SwiftUI
import AppKit

@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published var state: CCAState?
    @Published var busyAccount: String?
    @Published var busyGlobal = false
    @Published var lastOutput = ""
    @Published var error: String?

    var openMainWindow: (() -> Void)?
    private var refreshing = false
    private var refreshAgain = false
    private var lastRefresh = Date.distantPast
    private var pendingColors: [String: String] = [:]
    private var timer: Timer?

    var busy: Bool { busyGlobal || busyAccount != nil }
    var accounts: [CCAAccount] { state?.accounts ?? [] }

    // MARK: Refresh

    nonisolated static func fetch() async -> (state: CCAState?, error: String?) {
        let r = await CCARunner.run(["list", "--json"], timeout: 15)
        guard r.status == 0 else {
            let msg = (r.stderr + r.stdout).trimmingCharacters(in: .whitespacesAndNewlines)
            return (nil, msg.isEmpty ? "cca list --json failed (exit \(r.status))" : msg)
        }
        let data = Data(r.stdout.utf8)
        do {
            return (try JSONDecoder().decode(CCAState.self, from: data), nil)
        } catch {
            return (nil, "Could not read cca output (\(error.localizedDescription)):\n" + String(decoding: data.prefix(300), as: UTF8.self))
        }
    }

    func refresh() async {
        if refreshing { refreshAgain = true; return }
        refreshing = true
        defer { refreshing = false }
        repeat {
            refreshAgain = false
            lastRefresh = Date()
            let r = await Store.fetch()
            if let s = r.state {
                state = s
                error = nil
                applyPendingColors(s)
            } else {
                error = r.error
            }
        } while refreshAgain
    }

    private func applyPendingColors(_ s: CCAState) {
        for a in s.accounts where a.loggedIn {
            if let c = pendingColors.removeValue(forKey: a.name) {
                Task { await exec(["app", a.name, c], account: a.name) }
            }
        }
    }

    func start() {
        guard timer == nil else { return }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in await Store.shared.refresh() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { @MainActor in Store.shared.tick() }
        }
        Task { await refresh() }
    }

    private func tick() {
        let visible = NSApp.windows.contains { $0.isVisible && !$0.isMiniaturized && $0.canBecomeMain }
        if visible || Date().timeIntervalSince(lastRefresh) >= 30 { Task { await refresh() } }
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = NSApp.windows.first(where: { $0.canBecomeMain && $0.isVisible }) {
            w.makeKeyAndOrderFront(nil)
        } else {
            openMainWindow?()
        }
    }

    // MARK: Commands

    @discardableResult
    func exec(_ args: [String], account: String? = nil) async -> CCAResult {
        if let a = account { busyAccount = a } else { busyGlobal = true }
        let r = await CCARunner.run(args)
        busyAccount = nil
        busyGlobal = false
        var text = "$ cca " + args.joined(separator: " ") + "\n" + r.stdout
        if !r.stderr.isEmpty { text += (text.hasSuffix("\n") ? "" : "\n") + r.stderr }
        if r.status != 0 { text += (text.hasSuffix("\n") ? "" : "\n") + "[exit \(r.status)]" }
        lastOutput = text
        await refresh()
        return r
    }

    func open(_ n: String) { Task { await exec(["open", n], account: n) } }
    func makeApp(_ n: String, color: String? = nil) { Task { await exec(["app", n] + (color.map { [$0] } ?? []), account: n) } }
    func unbind(_ dir: String, account n: String) { Task { await exec(["unbind", dir], account: n) } }
    func bind(_ n: String, dir: String) { Task { await exec(["bind", n, dir], account: n) } }
    func backup() { Task { await exec(["backup"]) } }
    func setAutobackup(_ on: Bool) { Task { await exec(["autobackup", on ? "on" : "off"]) } }
    func remove(_ n: String) { Task { await exec(["remove", n], account: n) } }

    func restoreArgs(_ n: String, snapshot: String?, dryRun: Bool) -> [String] {
        ["restore", n] + (snapshot.map { [$0] } ?? []) + (dryRun ? ["-n"] : [])
    }

    /// Dry run: output only, no busy state, no refresh.
    func restoreDryRun(_ n: String, snapshot: String?) async -> CCAResult {
        await CCARunner.run(restoreArgs(n, snapshot: snapshot, dryRun: true))
    }

    func restore(_ n: String, snapshot: String?) async -> CCAResult {
        await exec(restoreArgs(n, snapshot: snapshot, dryRun: false), account: n)
    }

    // MARK: Terminal flows

    private func terminal(_ lines: [String]) {
        guard CCARunner.installed else { lastOutput = CCARunner.notInstalled; return }
        Task { if let e = await CCARunner.terminal(lines) { lastOutput = e } }
    }

    func login(_ n: String) { terminal(CCARunner.ccaLines(["login", n])) }

    func newTerminal(_ n: String) { terminal(CCARunner.newTerminalLines(n)) }

    func add(_ n: String, email: String, sso: Bool, color: String?) {
        var args = ["add", n]
        if !email.isEmpty { args += ["--email", email] }
        if sso { args.append("--sso") }
        if let c = color, !c.isEmpty { pendingColors[n] = c }
        terminal(CCARunner.ccaLines(args))
    }
}
