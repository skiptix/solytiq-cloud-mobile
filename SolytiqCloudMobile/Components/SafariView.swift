import SwiftUI
import SafariServices

/// §16 — an in-app browser (SFSafariViewController) used to view public share
/// pages (`/share/:token`, etc.) without leaving the app. Mobile doesn't
/// reimplement the share pages natively; it points Safari at the connected
/// server's public URL.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// §16 — a small sheet that accepts a share link or a raw token and opens it in
/// the in-app browser against the connected server. The Universal-Links path
/// (tapping a `/share/*` link straight into the app) is a backend/nginx
/// `apple-app-site-association` config change tracked separately; this is the
/// always-available manual fallback.
struct OpenSharedLinkSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var resolved: URL?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Share link or token", text: $input)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } footer: {
                    Text("Paste a share link you were sent, or just its token, to view it here.")
                }
                if let error {
                    Text(error).font(.system(size: 12.5)).foregroundStyle(SCColor.danger)
                }
                Button("Open") { open() }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .navigationTitle("Open Shared Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .sheet(item: $resolved) { url in SafariView(url: url) }
        }
    }

    private func open() {
        error = nil
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // A full URL opens as-is; a bare token resolves against the server.
        if trimmed.lowercased().hasPrefix("http"), let url = URL(string: trimmed) {
            resolved = url
        } else if let base = appState.serverURL {
            let token = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
            resolved = base.appendingPathComponent("share").appendingPathComponent(token)
        } else {
            error = "Connect to a server first, or paste a full https link."
        }
    }
}

/// Lets `URL` be used as a SwiftUI `.sheet(item:)` identity.
extension URL: Identifiable { public var id: String { absoluteString } }
