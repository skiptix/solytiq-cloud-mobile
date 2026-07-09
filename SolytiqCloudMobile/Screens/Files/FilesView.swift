import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @EnvironmentObject var sync: SyncEngine
    @State private var files: [AppFileItem] = []
    @State private var showImporter = false
    @State private var uploading = false
    @State private var errorMessage: String?

    private var totalBytes: Int { files.reduce(0) { $0 + $1.size } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    StorageBarView(usedBytes: totalBytes, totalBytes: 15_000_000_000)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SCColor.card))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
                        .padding(.horizontal, 18)

                    if let errorMessage {
                        Text(errorMessage).font(.system(size: 12.5)).foregroundStyle(SCColor.danger).padding(.horizontal, 24)
                    }

                    if files.isEmpty {
                        Card { EmptyRowView(text: uploading ? "Uploading…" : "No files yet. Tap + to upload.") }
                    } else {
                        Card {
                            ForEach(Array(files.enumerated()), id: \.element.id) { idx, file in
                                fileRow(file, showDivider: idx < files.count - 1)
                            }
                        }
                    }
                }
                .padding(.bottom, 110).padding(.top, 8)
            }
            .background(SCColor.page)
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showImporter = true } label: { Image(systemName: "plus.circle.fill") }
                }
                ToolbarItem(placement: .topBarTrailing) { ProfileToolbarButton() }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item]) { result in
                Task { await handleImport(result) }
            }
            .task { await reload() }
            .refreshable { await reload() }
            .onChange(of: sync.entityRevisions) { _, _ in
                Task { await reload() }
            }
        }
    }

    private func fileRow(_ file: AppFileItem, showDivider: Bool) -> some View {
        HStack(spacing: 12) {
            FileBadgeView(mime: file.mimeType, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(file.name).font(.system(size: 14, weight: .medium)).lineLimit(1)
                Text(sizeLabel(file.size)).font(.system(size: 11)).foregroundStyle(SCColor.text4)
            }
            Spacer()
            if file.isPublic {
                Image(systemName: "globe").font(.system(size: 12)).foregroundStyle(SCColor.success)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { router.sheet = .filePreview(file) }
        .overlay(alignment: .bottom) { if showDivider { Divider() } }
    }

    private func sizeLabel(_ bytes: Int) -> String {
        let d = Double(bytes)
        if d >= 1e6 { return String(format: "%.1f MB", d / 1e6) }
        return String(format: "%.0f KB", d / 1e3)
    }

    private func handleImport(_ result: Result<URL, Error>) async {
        guard case .success(let url) = result else { return }
        uploading = true
        defer { uploading = false }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            _ = try await store.uploadFile(name: url.lastPathComponent, mimeType: mime, data: data)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reload() async { files = await store.files() }
}
