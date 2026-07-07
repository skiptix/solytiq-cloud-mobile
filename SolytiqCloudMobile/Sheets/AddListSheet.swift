import SwiftUI

/// 3-step wizard (name/icon → sections → visibility) — the visibility step
/// only appears in server mode, per the design spec ("sharing/visibility
/// doesn't make sense when not connected to a server").
struct AddListSheet: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var folderId: String?

    @State private var step = 0
    @State private var name = ""
    @State private var emoji = "📋"
    @State private var colorHex = "#5e4dbb"
    @State private var sectionNames: [String] = ["Tasks"]
    @State private var newSection = ""
    @State private var isPublic = false

    private var totalSteps: Int { appState.mode == .server ? 3 : 2 }
    private var canAdvance: Bool { step == 0 ? !name.trimmingCharacters(in: .whitespaces).isEmpty : true }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule().fill(i <= step ? SCColor.primary : SCColor.border).frame(height: 4)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8)

                Group {
                    switch step {
                    case 0: nameStep
                    case 1: sectionsStep
                    default: visibilityStep
                    }
                }
                Spacer()
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(step == totalSteps - 1 ? "Create" : "Next") {
                        if step == totalSteps - 1 { Task { await create() } } else { step += 1 }
                    }
                    .disabled(!canAdvance)
                }
            }
        }
    }

    private var nameStep: some View {
        VStack(spacing: 14) {
            TextField("📋", text: $emoji).font(.system(size: 30)).multilineTextAlignment(.center).frame(width: 60)
            TextField("List name", text: $name).font(.system(size: 18, weight: .semibold)).multilineTextAlignment(.center)
            HStack(spacing: 10) {
                ForEach(["#5e4dbb", "#10B981", "#ea580c", "#2563EB", "#db2777"], id: \.self) { hex in
                    Circle().fill(Color(hex: hex)).frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(.primary, lineWidth: colorHex == hex ? 2 : 0))
                        .onTapGesture { colorHex = hex }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var sectionsStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sections").font(.system(size: 13, weight: .bold)).foregroundStyle(SCColor.text3).padding(.horizontal, 24)
            List {
                ForEach(sectionNames, id: \.self) { Text($0) }
                    .onDelete { idx in sectionNames.remove(atOffsets: idx) }
                HStack {
                    TextField("Section name", text: $newSection)
                    Button("Add") {
                        let t = newSection.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty else { return }
                        sectionNames.append(t); newSection = ""
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var visibilityStep: some View {
        VStack(spacing: 14) {
            Toggle(isOn: $isPublic) {
                VStack(alignment: .leading) {
                    Text("Visible to workspace").font(.system(size: 14, weight: .semibold))
                    Text("Other members of this workspace can see this list.").font(.system(size: 12)).foregroundStyle(SCColor.text3)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func create() async {
        let newList = await store.createList(name: name.trimmingCharacters(in: .whitespaces), emoji: emoji, colorHex: colorHex,
                                              folderId: folderId, isPublic: isPublic)
        if let newList {
            for section in sectionNames.dropFirst() {
                await store.addSection(listId: newList.id, label: section, emoji: nil)
            }
        }
        dismiss()
    }
}
