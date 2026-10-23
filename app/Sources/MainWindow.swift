import SwiftUI

struct MainWindow: View {
    @ObservedObject var store: Store
    @Environment(\.openWindow) private var openWindow
    @State private var selection: String?
    @State private var showAdd = false

    var body: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 340)
        } detail: {
            VStack(spacing: 0) {
                if let error = store.error {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    Divider()
                }
                if let account = store.accounts.first(where: { $0.name == selection }) {
                    AccountView(store: store, account: account)
                } else {
                    Text(store.state == nil ? "Loading accounts…" : "Select an account")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if !store.lastOutput.isEmpty { Divider(); OutputPanel(store: store) }
            }
        }
        .frame(minWidth: 820, minHeight: 540)
        .toolbar {
            ToolbarItemGroup {
                if store.busy { ProgressView().controlSize(.small) }
                Button { showAdd = true } label: { Label("Add account", systemImage: "plus") }
                    .help("Add account")
                Button { store.backup() } label: { Label("Backup now", systemImage: "tray.and.arrow.down") }
                    .help("Backup now")
                    .disabled(store.busy)
                Toggle(isOn: Binding(get: { store.state?.autobackup ?? false }, set: { store.setAutobackup($0) })) {
                    Label("Autobackup", systemImage: "clock.arrow.circlepath")
                }
                .toggleStyle(.button)
                .help("Daily autobackup")
                .disabled(store.busy || store.state == nil)
                Button { Task { await store.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .help("Refresh")
            }
        }
        .sheet(isPresented: $showAdd) { AddAccountSheet(store: store) }
        .onAppear { store.openMainWindow = { openWindow(id: "main") } }
        .onChange(of: store.accounts) { accounts in
            if !accounts.contains(where: { $0.name == selection }) {
                let pick = (accounts.first(where: { $0.isDefault }) ?? accounts.first)?.name
                DispatchQueue.main.async { selection = pick }
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Accounts") {
                ForEach(store.accounts) { a in
                    HStack(spacing: 8) {
                        ColorDot(color: a.color)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.name).fontWeight(.medium)
                            if let email = a.email { Text(email).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer(minLength: 4)
                        if a.isDefault { Tag(text: "default", color: .secondary) }
                        if a.running { Tag(text: "running", color: .green) }
                    }
                    .tag(a.name)
                }
            }
            Section("Backups") {
                if let snaps = store.state?.snapshots, !snaps.isEmpty {
                    ForEach(snaps, id: \.self) { s in
                        Label(s, systemImage: "clock").font(.system(.caption, design: .monospaced))
                    }
                } else {
                    Text("No backups yet").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct Tag: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

struct OutputPanel: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Output").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if store.busy { ProgressView().controlSize(.small) }
                Button("Clear") { store.lastOutput = "" }.controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            ScrollView {
                Text(store.lastOutput)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
            .frame(height: 140)
        }
        .background(.bar)
    }
}
