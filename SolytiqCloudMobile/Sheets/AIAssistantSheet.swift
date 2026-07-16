import SwiftUI
import UniformTypeIdentifiers

struct AIAssistantSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    /// Stable id for the local greeting placeholder so it can be excluded from
    /// the context sent to the model.
    static let greetingId = "sc.ai.greeting"

    @State private var messages: [AppChatMessage] = [
        AppChatMessage(id: greetingId, role: "assistant", content: "Hi! I'm your Solytiq AI assistant. Ask me about your tasks, lists, or schedule.")
    ]
    @State private var sessionId: String?
    @State private var input = ""
    @State private var sending = false
    @State private var showImporter = false
    @State private var uploadingFile = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(messages) { bubble($0) }
                            if sending {
                                HStack { ProgressView().padding(.leading, 4); Spacer() }
                            }
                        }
                        .padding(16)
                        .id("bottom")
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
                Divider()
                HStack(spacing: 10) {
                    Button { showImporter = true } label: {
                        if uploadingFile { ProgressView() }
                        else { Image(systemName: "paperclip").font(.system(size: 20)).foregroundStyle(SCColor.text3) }
                    }
                    .disabled(uploadingFile || sending)

                    TextField("Ask Sol…", text: $input, axis: .vertical)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SCColor.cardTinted))
                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 28)).foregroundStyle(SCColor.primary)
                    }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || sending)
                }
                .padding(12)
            }
            .navigationTitle("Sol Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data, .item, .content],
                          allowsMultipleSelection: false) { result in
                Task { await attachFile(result) }
            }
        }
    }

    private func attachFile(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        uploadingFile = true
        defer { uploadingFile = false }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        if let sid = try? await store.uploadAIFile(sessionId: sessionId, fileName: url.lastPathComponent, mimeType: mime, data: data) {
            sessionId = sid
            messages.append(AppChatMessage(role: "assistant", content: "📎 Attached **\(url.lastPathComponent)** — ask me anything about it."))
        }
    }

    private func bubble(_ message: AppChatMessage) -> some View {
        HStack {
            if message.role == "assistant" { Spacer(minLength: 40) } else { Spacer(minLength: 0) }
            Text(message.content)
                .font(.system(size: 14))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(message.role == "user" ? SCColor.primary : SCColor.card))
                .foregroundStyle(message.role == "user" ? .white : SCColor.text)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(message.role == "user" ? .clear : SCColor.border, lineWidth: 0.5))
            if message.role == "user" { Spacer(minLength: 40) } else { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        // Snapshot the conversation the model should see *before* appending the
        // new turn (the greeting is a local placeholder — drop it so it isn't
        // sent as real context).
        let prior = messages.filter { $0.id != Self.greetingId }
        messages.append(AppChatMessage(role: "user", content: text))
        sending = true
        defer { sending = false }
        if let result = await store.sendAIMessage(sessionId: sessionId, priorMessages: prior, content: text) {
            sessionId = result.sessionId
            messages.append(result.reply)
        }
    }
}
