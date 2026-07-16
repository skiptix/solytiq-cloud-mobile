import SwiftUI

/// §9 — a markdown document editor with a live preview. Raw markdown is edited
/// in a `TextEditor`; the preview uses a lightweight in-house renderer (no
/// third-party dependency, per the project convention) covering the subset the
/// web's `MarkdownView` uses: headings, lists, blockquotes, code, and inline
/// emphasis. Server mode only.
struct MarkdownListView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    /// nil → creating a new document.
    var markdownListId: String?

    @State private var title = ""
    @State private var content = ""
    @State private var emoji = "📝"
    @State private var mode: Mode = .edit
    @State private var loaded = false
    @State private var savedId: String?
    @State private var confirmDelete = false
    @State private var saving = false

    enum Mode: String, CaseIterable, Identifiable { case edit = "Edit", preview = "Preview"; var id: String { rawValue } }

    private var isNew: Bool { markdownListId == nil && savedId == nil }
    private var effectiveId: String? { markdownListId ?? savedId }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Title", text: $title)
                    .font(.system(size: 20, weight: .bold))
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 6)

                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.bottom, 8)

                Divider()

                if mode == .edit {
                    TextEditor(text: $content)
                        .font(.system(size: 15, design: .monospaced))
                        .padding(.horizontal, 12)
                } else {
                    ScrollView {
                        MarkdownRenderedView(markdown: content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                }
            }
            .background(SCColor.page)
            .navigationTitle(isNew ? "New Markdown" : "Markdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Save", systemImage: "checkmark") { Task { await save() } }
                        if !isNew {
                            Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        }
                    } label: {
                        if saving { ProgressView() } else { Image(systemName: "ellipsis.circle") }
                    }
                }
            }
            .confirmDelete(isPresented: $confirmDelete, title: "Delete Document?", message: "\"\(title)\" will be deleted.") {
                Task {
                    if let id = effectiveId { await store.deleteMarkdownList(id: id) }
                    dismiss()
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        guard !loaded else { return }
        loaded = true
        guard let id = markdownListId, let doc = await store.markdownList(id: id) else { return }
        title = doc.title
        content = doc.content
        emoji = doc.emoji ?? "📝"
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : title
        if let id = effectiveId {
            _ = await store.updateMarkdownList(id: id, title: trimmedTitle, content: content, emoji: emoji)
        } else {
            if let created = await store.createMarkdownList(title: trimmedTitle, content: content, emoji: emoji) {
                savedId = created.id
            }
        }
    }
}

/// A minimal, dependency-free markdown block renderer. Handles ATX headings,
/// unordered/ordered lists, blockquotes, fenced code blocks, horizontal rules
/// and paragraphs; inline emphasis/links/code are rendered through the system's
/// `AttributedString(markdown:)` inline parser.
struct MarkdownRenderedView: View {
    var markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                block.view
            }
        }
    }

    private enum Block {
        case heading(level: Int, text: String)
        case bullet(String)
        case ordered(index: Int, String)
        case quote(String)
        case code(String)
        case rule
        case paragraph(String)

        @ViewBuilder var view: some View {
            switch self {
            case .heading(let level, let text):
                inline(text)
                    .font(.system(size: [26, 22, 19, 17, 15, 14][min(level - 1, 5)], weight: .bold))
                    .foregroundStyle(SCColor.text)
            case .bullet(let text):
                HStack(alignment: .top, spacing: 8) {
                    Text("•").foregroundStyle(SCColor.primary)
                    inline(text).foregroundStyle(SCColor.text2)
                }
            case .ordered(let index, let text):
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index).").foregroundStyle(SCColor.primary).monospacedDigit()
                    inline(text).foregroundStyle(SCColor.text2)
                }
            case .quote(let text):
                HStack(spacing: 10) {
                    Rectangle().fill(SCColor.primary.opacity(0.4)).frame(width: 3)
                    inline(text).italic().foregroundStyle(SCColor.text3)
                }
            case .code(let text):
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(SCColor.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(SCColor.hover))
            case .rule:
                Divider()
            case .paragraph(let text):
                inline(text).foregroundStyle(SCColor.text2)
            }
        }

        /// Inline-formats a single line via the system markdown parser, falling
        /// back to plain text if it can't be parsed.
        private func inline(_ text: String) -> Text {
            if let attributed = try? AttributedString(markdown: text,
                                                      options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                return Text(attributed)
            }
            return Text(text)
        }
    }

    private var blocks: [Block] {
        var result: [Block] = []
        var inCode = false
        var codeLines: [String] = []
        var orderedIndex = 0

        for rawLine in markdown.components(separatedBy: "\n") {
            let line = rawLine

            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inCode {
                    result.append(.code(codeLines.joined(separator: "\n")))
                    codeLines = []
                    inCode = false
                } else {
                    inCode = true
                }
                continue
            }
            if inCode { codeLines.append(line); continue }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { orderedIndex = 0; continue }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                result.append(.rule); continue
            }
            if let hashes = trimmed.range(of: "^#{1,6} ", options: .regularExpression) {
                let level = trimmed.distance(from: trimmed.startIndex, to: hashes.upperBound) - 1
                result.append(.heading(level: level, text: String(trimmed[hashes.upperBound...])))
                continue
            }
            if trimmed.hasPrefix("> ") {
                result.append(.quote(String(trimmed.dropFirst(2)))); continue
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                orderedIndex = 0
                result.append(.bullet(String(trimmed.dropFirst(2)))); continue
            }
            if let match = trimmed.range(of: "^\\d+\\. ", options: .regularExpression) {
                orderedIndex += 1
                result.append(.ordered(index: orderedIndex, String(trimmed[match.upperBound...]))); continue
            }
            orderedIndex = 0
            result.append(.paragraph(trimmed))
        }
        if inCode, !codeLines.isEmpty { result.append(.code(codeLines.joined(separator: "\n"))) }
        return result
    }
}
