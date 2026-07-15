import SwiftUI

/// §1.7 — move a task into another list/section. Mirrors web's `MoveTaskModal`:
/// pick a destination list, then one of its sections. Server mode only.
struct MoveTaskSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    var task: AppTask

    @State private var lists: [AppList] = []
    @State private var selectedListId: String?
    @State private var selectedSectionId: String?
    @State private var isMoving = false

    private var selectedList: AppList? { lists.first { $0.id == selectedListId } }
    private var canMove: Bool {
        guard let selectedListId, let selectedSectionId else { return false }
        // A no-op (same list + section) isn't a move.
        return !(selectedListId == task.listId && selectedSectionId == task.sectionId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination list") {
                    ForEach(lists) { list in
                        Button {
                            selectedListId = list.id
                            // Default to the first section of the chosen list.
                            selectedSectionId = list.sections.first?.id
                        } label: {
                            HStack {
                                Text(list.emoji ?? "📋")
                                Text(list.name).foregroundStyle(SCColor.text)
                                Spacer()
                                if list.id == selectedListId {
                                    Image(systemName: "checkmark").foregroundStyle(SCColor.primary)
                                }
                            }
                        }
                    }
                }

                if let selectedList, !selectedList.sections.isEmpty {
                    Section("Section") {
                        ForEach(selectedList.sections) { section in
                            Button {
                                selectedSectionId = section.id
                            } label: {
                                HStack {
                                    if let emoji = section.emoji { Text(emoji) }
                                    Text(section.label).foregroundStyle(SCColor.text)
                                    Spacer()
                                    if section.id == selectedSectionId {
                                        Image(systemName: "checkmark").foregroundStyle(SCColor.primary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Move Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") { Task { await move() } }.disabled(!canMove || isMoving)
                }
            }
            .task {
                lists = await store.lists().filter { !$0.isArchived }
                selectedListId = task.listId
                selectedSectionId = task.sectionId
            }
        }
    }

    private func move() async {
        isMoving = true
        defer { isMoving = false }
        await store.moveTask(id: task.id, toListId: selectedListId, toSectionId: selectedSectionId)
        dismiss()
    }
}
