import SwiftUI
import AppKit

struct AccountView: View {
    @ObservedObject var store: Store
    var account: CCAAccount
    @State private var showRestore = false
    @State private var confirmRemove = false

    private var name: String { account.name }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                actions
                Divider()
                folders
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(store.busy)
        .sheet(isPresented: $showRestore) { RestoreSheet(store: store, account: name) }
        .alert("Remove \(name)?", isPresented: $confirmRemove) {
            Button("Remove", role: .destructive) { store.remove(name) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(account.isDefault
                 ? "This removes the login and the launcher for \(name). Your ~/.claude folder stays as it is."
                 : "This removes the account \(name), its login and its launcher.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ColorDot(color: account.color, size: 22).padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(name).font(.title2.bold())
                    if account.isDefault { Tag(text: "default", color: .secondary) }
                    if store.busyAccount == name { ProgressView().controlSize(.small) }
                }
                if account.email != nil || account.org != nil {
                    Text([account.email, account.org].compactMap { $0 }.joined(separator: " · ")).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Label(account.running ? "Running" : "Not running", systemImage: "circle.fill")
                        .foregroundStyle(account.running ? Color.green : Color.secondary)
                    Label(account.loggedIn ? "Logged in" : "Not logged in",
                          systemImage: account.loggedIn ? "checkmark.circle" : "exclamationmark.circle")
                        .foregroundStyle(account.loggedIn ? Color.secondary : Color.orange)
                }
                .font(.caption)
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { store.open(name) } label: { Label("Open Claude app", systemImage: "arrow.up.forward.app") }
                    .buttonStyle(.borderedProminent)
                if account.app == nil {
                    Button { store.makeApp(name) } label: { Label("Make app", systemImage: "app.badge") }
                }
                Picker("Colour", selection: Binding(get: { account.color ?? "" }, set: setColor)) {
                    if account.color == nil { Text("None").tag("") }
                    ForEach(store.state?.colors ?? [], id: \.self) { Text($0.capitalized).tag($0) }
                }
                .fixedSize()
            }
            HStack {
                Button { store.newTerminal(name) } label: { Label("New Terminal", systemImage: "terminal") }
                Button { store.login(name) } label: { Label("Log in again", systemImage: "person.badge.key") }
                Button { showRestore = true } label: { Label("Restore…", systemImage: "arrow.counterclockwise") }
                Button(role: .destructive) { confirmRemove = true } label: { Label("Remove…", systemImage: "trash") }
            }
        }
    }

    private func setColor(_ c: String) {
        guard !c.isEmpty, c != account.color else { return }
        store.makeApp(name, color: c)
    }

    private var folders: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Folders").font(.headline)
            if account.folders.isEmpty {
                Text("No folders use this account.").foregroundStyle(.secondary)
            }
            ForEach(account.folders, id: \.self) { dir in
                HStack {
                    Image(systemName: "folder").foregroundStyle(.secondary)
                    Text(dir).font(.system(.body, design: .monospaced)).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    Spacer()
                    Button("Unbind") { store.unbind(dir, account: name) }
                }
            }
            Button { bindFolder() } label: { Label("Bind folder…", systemImage: "plus") }
        }
    }

    private func bindFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Bind"
        panel.message = "Choose a folder that should use \(name)"
        if panel.runModal() == .OK, let url = panel.url { store.bind(name, dir: url.path) }
    }
}
