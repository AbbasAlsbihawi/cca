import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in Store.shared.start() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { Task { @MainActor in Store.shared.showMainWindow() } }
        return true
    }
}

@main
struct ClaudeAccountsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = Store.shared

    init() {
        guard CommandLine.arguments.contains("--dump-state") else { return }
        Task.detached {
            let r = await Store.fetch()
            if let s = r.state {
                print("\(s.accounts.count) accounts")
                exit(0)
            }
            print(r.error ?? "unknown error")
            exit(1)
        }
        dispatchMain()
    }

    var body: some Scene {
        Window("Claude Accounts", id: "main") {
            MainWindow(store: store)
        }
        MenuBarExtra("Claude Accounts", systemImage: "person.2.fill") {
            MenuBarContent(store: store)
        }
        .menuBarExtraStyle(.menu)
    }
}
