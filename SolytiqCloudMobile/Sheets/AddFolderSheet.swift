import SwiftUI

struct AddFolderSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "📁"
    @State private var colorHex = "#10B981"

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("📁", text: $emoji).font(.system(size: 34)).multilineTextAlignment(.center).frame(width: 64)
                TextField("Folder name", text: $name).font(.system(size: 18, weight: .semibold)).multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    ForEach(["#10B981", "#5e4dbb", "#ea580c", "#2563EB", "#db2777"], id: \.self) { hex in
                        Circle().fill(Color(hex: hex)).frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(.primary, lineWidth: colorHex == hex ? 2 : 0))
                            .onTapGesture { colorHex = hex }
                    }
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await store.createFolder(name: name.trimmingCharacters(in: .whitespaces), emoji: emoji, colorHex: colorHex)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
