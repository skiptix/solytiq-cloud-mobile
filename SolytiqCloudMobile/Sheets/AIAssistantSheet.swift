import SwiftUI

struct AIAssistantSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [AppChatMessage] = [
        AppChatMessage(role: "assistant", content: "Hi! I'm your Solytiq AI assistant. Ask me about your tasks, lists, or schedule.")
    ]
    @State private var sessionId: String?
    @State private var input = ""
    @State private var sending = false

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
                    TextField("Ask Sol…", text: $input, axis: .vertical)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SCColor.tinted))
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
        messages.append(AppChatMessage(role: "user", content: text))
        sending = true
        defer { sending = false }
        if let result = await store.sendAIMessage(sessionId: sessionId, content: text) {
            sessionId = result.sessionId
            messages.append(result.reply)
        }
    }
}
