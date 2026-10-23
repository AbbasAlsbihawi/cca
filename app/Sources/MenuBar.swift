import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var store: Store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if store.accounts.isEmpty {
            Text(store.error == nil ? "No accounts" : "cca unavailable")
        }
        ForEach(store.accounts) { a in
            Button {
                store.open(a.name)
            } label: {
                Label {
                    Text(a.name + (a.email.map { " — \($0)" } ?? "") + (a.running ? " ●" : ""))
                } icon: {
                    Image(nsImage: CCAColor.dotImage(a.color))
                }
            }
            .disabled(store.busy)
        }
        if !store.accounts.isEmpty {
            Divider()
            Menu("Account actions") {
                ForEach(store.accounts) { a in
                    Menu(a.name) {
                        Button("Open Claude") { store.open(a.name) }.disabled(store.busy)
                        Button("New Terminal") { store.newTerminal(a.name) }
                    }
                }
            }
        }
        Divider()
        Button("Backup now") { store.backup() }.disabled(store.busy)
        Button("Open window") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
