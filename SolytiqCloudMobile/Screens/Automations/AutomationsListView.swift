import SwiftUI

/// §10 — the automations gallery for the active workspace, with a per-row
/// enable/disable toggle and a create button. Presented as a sheet; taps push
/// into `AutomationEditorView`.
struct AutomationsListView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var sync: SyncEngine
    @Environment(\.dismiss) private var dismiss

    @State private var automations: [AppAutomation] = []
    @State private var loading = true
    @State private var newAutomationName = ""
    @State private var showCreate = false
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if automations.isEmpty {
                    ContentUnavailableView("No automations", systemImage: "bolt.badge.automatic",
                                           description: Text("Create trigger-and-action workflows that run on your lists and tasks."))
                } else {
                    List {
                        ForEach(automations) { automation in
                            Button { path.append(automation.id) } label: { row(automation) }
                        }
                        .onDelete { idx in
                            Task {
                                for i in idx { await store.deleteAutomation(id: automations[i].id) }
                                await reload()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Automations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { newAutomationName = ""; showCreate = true } label: { Image(systemName: "plus") }
                }
            }
            .navigationDestination(for: String.self) { id in
                AutomationEditorView(automationId: id)
            }
            .alert("New Automation", isPresented: $showCreate) {
                TextField("Name", text: $newAutomationName)
                Button("Create") { Task { await create() } }
                Button("Cancel", role: .cancel) {}
            }
            .task { await reload() }
            .onChange(of: sync.entityRevisions) { _, _ in Task { await reload() } }
        }
    }

    private func row(_ automation: AppAutomation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.badge.automatic")
                .foregroundStyle(automation.enabled ? SCColor.primary : SCColor.text4)
            VStack(alignment: .leading, spacing: 2) {
                Text(automation.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(SCColor.text)
                Text("\(automation.actions.count) action\(automation.actions.count == 1 ? "" : "s")")
                    .font(.system(size: 11.5)).foregroundStyle(SCColor.text4)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { automation.enabled },
                set: { on in Task { await store.setAutomationEnabled(id: automation.id, enabled: on); await reload() } }
            ))
            .labelsHidden()
        }
    }

    private func create() async {
        let name = newAutomationName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let created = await store.createAutomation(name: name) else { return }
        await reload()
        path.append(created.id)
    }

    private func reload() async {
        automations = await store.automations()
        loading = false
    }
}
