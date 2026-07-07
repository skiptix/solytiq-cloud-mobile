import SwiftUI
import UIKit

struct FilePreviewSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    var file: AppFileItem
    @State private var isPublic: Bool
    @State private var confirmDelete = false

    init(file: AppFileItem) {
        self.file = file
        _isPublic = State(initialValue: file.isPublic)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                FileBadgeView(mime: file.mimeType, size: 84).padding(.top, 12)
                Text(file.name).font(.system(size: 16, weight: .bold)).multilineTextAlignment(.center).padding(.horizontal, 20)

                Toggle("Public link", isOn: $isPublic)
                    .padding(.horizontal, 24)
                    .onChange(of: isPublic) { _, newValue in
                        Task { _ = await store.setFileShare(id: file.id, isPublic: newValue, password: nil, expiresAt: nil) }
                    }

                if isPublic, let shareUrl = file.shareUrl {
                    HStack {
                        Text(shareUrl).font(.system(size: 12)).lineLimit(1).foregroundStyle(SCColor.text3)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = shareUrl
                        } label: { Image(systemName: "doc.on.doc") }
                    }
                    .padding(.horizontal, 24)
                }

                if let url = store.fileDownloadURL(id: file.id) {
                    Link(destination: url) {
                        Label("Open / Download", systemImage: "arrow.down.circle")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SCColor.primaryBg))
                    }
                    .padding(.horizontal, 24)
                }

                Button("Delete File", role: .destructive) { confirmDelete = true }
                    .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .confirmDelete(isPresented: $confirmDelete, title: "Delete File?", message: "\"\(file.name)\" will be permanently deleted.") {
                Task { await store.deleteFile(id: file.id); dismiss() }
            }
        }
    }
}
