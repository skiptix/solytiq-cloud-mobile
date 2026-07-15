import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct FilesView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sync: SyncEngine
    @State private var files: [AppFileItem] = []
    @State private var showImporter = false
    @State private var uploading = false
    @State private var errorMessage: String?
    @State private var copiedId: String?
    // §5.1 authoritative quota from the server (falls back to summed sizes).
    @State private var storageUsed: Int?
    @State private var storageQuota: Int?

    private var totalBytes: Int { files.reduce(0) { $0 + $1.size } }
    private var isAdmin: Bool { appState.currentUser?.isAdmin ?? false }
    private var recent: [AppFileItem] { Array(files.prefix(2)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    storageCard

                    if let errorMessage {
                        Text(errorMessage).font(.system(size: 12.5)).foregroundStyle(SCColor.danger).padding(.horizontal, 24)
                    }

                    if !recent.isEmpty {
                        SectionHeaderView(title: "Recent", rightText: "\(files.count) files")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(recent) { recentCard($0) }
                        }
                        .padding(.horizontal, 18)
                    }

                    uploadDropzone

                    SectionHeaderView(title: "All Files")
                    Card {
                        if files.isEmpty {
                            EmptyRowView(text: "No files yet. Upload your first file!")
                        } else {
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
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data, .item, .content],
                          allowsMultipleSelection: true) { result in
                Task { await handleImport(result) }
            }
            .task { await reload() }
            .refreshable { await reload() }
            .onChange(of: sync.entityRevisions) { _, _ in
                Task { await reload() }
            }
        }
    }

    // ── Storage card ──
    private var storageCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(SCColor.primaryBg)
                    Image(systemName: "externaldrive.fill").font(.system(size: 16)).foregroundStyle(SCColor.primary)
                }
                .frame(width: 34, height: 34)
                Text("Storage").font(.system(size: 14, weight: .semibold)).foregroundStyle(SCColor.text)
                Spacer()
                if isAdmin {
                    Text("ADMIN · UNLIMITED")
                        .font(.system(size: 9, weight: .bold)).tracking(0.4)
                        .foregroundStyle(SCColor.primary)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(SCColor.primaryBg))
                }
            }
            StorageBarView(usedBytes: storageUsed ?? totalBytes,
                           totalBytes: storageQuota ?? 15_000_000_000, isAdmin: isAdmin)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SCColor.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
        .padding(.horizontal, 22)
    }

    // ── Recent file card (2-up grid) ──
    private func recentCard(_ file: AppFileItem) -> some View {
        Button { router.sheet = .filePreview(file) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    FileBadgeView(mime: file.mimeType, size: 42)
                    Spacer()
                    visibilityPill(file.isPublic)
                }
                Text(file.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(SCColor.text).lineLimit(1)
                Text("\(sizeLabel(file.size)) · \(dateLabel(file.createdAt))")
                    .font(.system(size: 11)).foregroundStyle(SCColor.text4)
                if file.isPublic {
                    let copied = copiedId == file.id
                    Button { copyLink(file) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "link").font(.system(size: 11))
                            Text(copied ? "Copied!" : "Copy Link").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(copied ? SCColor.success : SCColor.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(copied ? SCColor.success.opacity(0.12) : SCColor.primaryBg))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SCColor.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // ── Upload dropzone ──
    private var uploadDropzone: some View {
        Button { showImporter = true } label: {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SCColor.primaryBg)
                    Image(systemName: uploading ? "arrow.up.circle" : "icloud.and.arrow.up.fill")
                        .font(.system(size: 24)).foregroundStyle(SCColor.primary)
                }
                .frame(width: 52, height: 52)
                Text(uploading ? "Uploading…" : "Tap to upload")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(SCColor.primary)
                Text("JPEG, PNG, PDF, ZIP · up to 200 MB")
                    .font(.system(size: 12)).foregroundStyle(SCColor.text4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28).padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(SCColor.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                    .foregroundStyle(SCColor.primary.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
        .disabled(uploading)
        .padding(.horizontal, 18)
    }

    // ── All-files row ──
    private func fileRow(_ file: AppFileItem, showDivider: Bool) -> some View {
        HStack(spacing: 13) {
            FileBadgeView(mime: file.mimeType, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(file.name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(SCColor.text).lineLimit(1)
                HStack(spacing: 7) {
                    Text(sizeLabel(file.size)).font(.system(size: 11.5)).foregroundStyle(SCColor.text4)
                    Text("·").foregroundStyle(SCColor.text4)
                    Text(dateLabel(file.createdAt)).font(.system(size: 11.5)).foregroundStyle(SCColor.text4)
                    if file.hasPassword {
                        Label("pw", systemImage: "lock.fill").font(.system(size: 10)).foregroundStyle(SCColor.text4)
                    }
                }
            }
            Spacer()
            visibilityPill(file.isPublic)
            Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(SCColor.text4)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .contentShape(Rectangle())
        .onTapGesture { router.sheet = .filePreview(file) }
        .overlay(alignment: .bottom) { if showDivider { Divider().opacity(0.5).padding(.leading, 16) } }
    }

    private func visibilityPill(_ isPublic: Bool) -> some View {
        Text(isPublic ? "PUBLIC" : "PRIVATE")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(isPublic ? SCColor.primary : SCColor.text4)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(isPublic ? SCColor.primaryBg : SCColor.hover))
    }

    private func copyLink(_ file: AppFileItem) {
        UIPasteboard.general.string = file.shareUrl ?? ""
        copiedId = file.id
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if copiedId == file.id { copiedId = nil }
        }
    }

    private func sizeLabel(_ bytes: Int) -> String {
        let d = Double(bytes)
        if d >= 1e6 { return String(format: "%.1f MB", d / 1e6) }
        return String(format: "%.0f KB", d / 1e3)
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func handleImport(_ result: Result<[URL], Error>) async {
        errorMessage = nil
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
            return
        case .success(let urls):
            guard !urls.isEmpty else { return }
            uploading = true
            defer { uploading = false }
            for url in urls {
                await upload(url)
            }
            await reload()
        }
    }

    private func upload(_ url: URL) async {
        // Files picked from iCloud / other providers are security-scoped; we
        // must open the scope before reading, but not every URL is scoped
        // (e.g. an "On My iPhone" path) so a false result isn't fatal.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            _ = try await store.uploadFile(name: url.lastPathComponent, mimeType: mime, data: data)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func reload() async {
        files = await store.files()
        if let info = await store.storageInfo() {
            storageUsed = info.used
            storageQuota = info.quota > 0 ? info.quota : nil
        }
    }
}
