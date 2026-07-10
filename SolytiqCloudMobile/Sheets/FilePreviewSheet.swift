import SwiftUI
import UIKit

/// File detail + share management. Mirrors the web `FilesScreen` share controls:
/// a public-link toggle with optional password and expiry, plus authenticated
/// download and delete.
struct FilePreviewSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    var file: AppFileItem
    @State private var isPublic: Bool
    @State private var hasPassword: Bool
    @State private var password: String = ""
    @State private var setPassword = false
    @State private var expiryEnabled: Bool
    @State private var expiryDate: Date
    @State private var shareUrl: String?

    @State private var confirmDelete = false
    @State private var downloading = false
    @State private var downloadedURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    init(file: AppFileItem) {
        self.file = file
        _isPublic = State(initialValue: file.isPublic)
        _hasPassword = State(initialValue: file.hasPassword)
        _shareUrl = State(initialValue: file.shareUrl)
        _expiryEnabled = State(initialValue: file.expiresAt != nil)
        _expiryDate = State(initialValue: ServerDate.parse(file.expiresAt) ?? (Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    FileBadgeView(mime: file.mimeType, size: 84).padding(.top, 12)
                    Text(file.name).font(.system(size: 16, weight: .bold)).multilineTextAlignment(.center).padding(.horizontal, 20)
                    Text(sizeLabel(file.size)).font(.system(size: 12)).foregroundStyle(SCColor.text4)

                    downloadButton

                    shareCard

                    if let errorMessage {
                        Text(errorMessage).font(.system(size: 12.5)).foregroundStyle(SCColor.danger).padding(.horizontal, 24)
                    }

                    Button("Delete File", role: .destructive) { confirmDelete = true }
                        .padding(.top, 4).padding(.bottom, 24)
                }
            }
            .navigationTitle("File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showShareSheet) {
                if let downloadedURL { ShareSheet(items: [downloadedURL]) }
            }
            .confirmDelete(isPresented: $confirmDelete, title: "Delete File?", message: "\"\(file.name)\" will be permanently deleted.") {
                Task { await store.deleteFile(id: file.id); dismiss() }
            }
        }
    }

    private var downloadButton: some View {
        Button {
            Task { await download() }
        } label: {
            HStack(spacing: 8) {
                if downloading { ProgressView().tint(SCColor.primary) }
                else { Image(systemName: "arrow.down.circle") }
                Text(downloading ? "Downloading…" : "Open / Share")
            }
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SCColor.primaryBg))
            .foregroundStyle(SCColor.primary)
        }
        .disabled(downloading)
        .padding(.horizontal, 24)
    }

    private var shareCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Public link", isOn: $isPublic)
                .onChange(of: isPublic) { _, _ in Task { await applyShare() } }

            if isPublic {
                if let shareUrl {
                    HStack {
                        Text(shareUrl).font(.system(size: 12)).lineLimit(1).truncationMode(.middle).foregroundStyle(SCColor.text3)
                        Spacer()
                        Button { UIPasteboard.general.string = shareUrl } label: { Image(systemName: "doc.on.doc") }
                    }
                }

                Divider()

                // Password protection
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Password", systemImage: "lock").font(.system(size: 13, weight: .medium))
                        Spacer()
                        if hasPassword && !setPassword {
                            Text("Set").font(.system(size: 11, weight: .semibold)).foregroundStyle(SCColor.success)
                            Button("Remove") { Task { await removePassword() } }
                                .font(.system(size: 12)).tint(SCColor.danger)
                        }
                    }
                    if setPassword || !hasPassword {
                        HStack {
                            SecureField("Optional password", text: $password)
                                .font(.system(size: 13))
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(SCColor.cardTinted))
                            Button("Save") { Task { await applyPassword() } }
                                .font(.system(size: 12, weight: .semibold))
                                .disabled(password.isEmpty)
                        }
                    }
                }

                Divider()

                // Expiry
                Toggle("Set expiry", isOn: $expiryEnabled)
                    .font(.system(size: 13))
                    .onChange(of: expiryEnabled) { _, on in Task { await applyExpiry(on ? expiryDate : nil) } }
                if expiryEnabled {
                    DatePicker("Expires", selection: $expiryDate, in: Date()..., displayedComponents: [.date])
                        .font(.system(size: 13))
                        .onChange(of: expiryDate) { _, _ in Task { await applyExpiry(expiryDate) } }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SCColor.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
        .padding(.horizontal, 24)
    }

    private func sizeLabel(_ bytes: Int) -> String {
        let d = Double(bytes)
        if d >= 1e6 { return String(format: "%.1f MB", d / 1e6) }
        return String(format: "%.0f KB", d / 1e3)
    }

    private func download() async {
        downloading = true
        defer { downloading = false }
        do {
            downloadedURL = try await store.downloadFile(file)
            showShareSheet = true
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func applyShare() async {
        if let updated = await store.setFileShare(id: file.id, isPublic: isPublic, password: nil, expiresAt: nil) {
            shareUrl = updated.shareUrl
        }
    }

    private func applyPassword() async {
        guard !password.isEmpty else { return }
        _ = await store.setFileShare(id: file.id, isPublic: true, password: password, expiresAt: nil)
        hasPassword = true
        setPassword = false
        password = ""
    }

    private func removePassword() async {
        _ = await store.setFileShare(id: file.id, isPublic: true, password: "", expiresAt: nil)
        hasPassword = false
        password = ""
    }

    private func applyExpiry(_ date: Date?) async {
        if let date {
            _ = await store.setFileShare(id: file.id, isPublic: true, password: nil,
                                         expiresAt: ISO8601DateFormatter().string(from: date))
        } else {
            _ = await store.setFileShare(id: file.id, isPublic: true, password: nil,
                                         expiresAt: nil, clearExpiry: true)
        }
    }
}
