import SwiftUI

struct AddAccountSheet: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var sso = false
    @State private var color = ""

    private var problem: String? {
        if name.isEmpty { return nil }
        if name.range(of: "^[a-z0-9][a-z0-9_-]*$", options: .regularExpression) == nil {
            return "Use lowercase letters, digits, - and _, starting with a letter or digit."
        }
        if store.accounts.contains(where: { $0.name == name }) { return "An account named \(name) already exists." }
        return nil
    }

    private var valid: Bool { !name.isEmpty && problem == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add account").font(.title3.bold())
            Form {
                TextField("Name", text: $name)
                if let problem = problem { Text(problem).font(.caption).foregroundStyle(.red) }
                TextField("Email (optional)", text: $email)
                Toggle("Single sign-on (SSO)", isOn: $sso)
                Picker("Colour", selection: $color) {
                    Text("None").tag("")
                    ForEach(store.state?.colors ?? [], id: \.self) { Text($0.capitalized).tag($0) }
                }
            }
            .formStyle(.grouped)
            Text("Terminal opens so you can log in. The launcher gets its colour once you are logged in.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add in Terminal") {
                    store.add(name, email: email.trimmingCharacters(in: .whitespaces), sso: sso, color: color.isEmpty ? nil : color)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!valid)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}

struct RestoreSheet: View {
    @ObservedObject var store: Store
    var account: String
    @Environment(\.dismiss) private var dismiss
    @State private var snapshot: String?
    @State private var preview = ""
    @State private var previewing = false
    @State private var previewOK = false
    @State private var restoring = false
    @State private var result: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Restore \(account)").font(.title3.bold())
            Picker("Snapshot", selection: $snapshot) {
                Text("Newest (let cca pick)").tag(String?.none)
                ForEach(store.state?.snapshots ?? [], id: \.self) { Text($0).tag(String?.some($0)) }
            }
            .disabled(restoring || result != nil)
            GroupBox {
                ScrollView {
                    Text(result ?? preview)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                }
                .frame(height: 180)
            } label: {
                HStack {
                    Text(result == nil ? "Dry run (nothing is changed yet)" : "Result")
                    if previewing || restoring { ProgressView().controlSize(.small) }
                }
            }
            HStack {
                Spacer()
                Button(result == nil ? "Cancel" : "Close") { dismiss() }.keyboardShortcut(.cancelAction)
                if result == nil {
                    Button("Restore") {
                        restoring = true
                        Task {
                            let r = await store.restore(account, snapshot: snapshot)
                            result = r.stdout + r.stderr + (r.status == 0 ? "" : "\n[exit \(r.status)]")
                            restoring = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(previewing || restoring || !previewOK)
                }
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear { snapshot = store.state?.snapshots.first }
        .task(id: snapshot) {
            previewing = true
            previewOK = false
            let r = await store.restoreDryRun(account, snapshot: snapshot)
            if !Task.isCancelled {
                preview = r.stdout + r.stderr + (r.status == 0 ? "" : "\n[exit \(r.status)]")
                previewOK = r.status == 0
                previewing = false
            }
        }
    }
}
