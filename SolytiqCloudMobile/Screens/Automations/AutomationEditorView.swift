import SwiftUI

/// §10 — the mobile automation editor: a vertical step-card list (one trigger
/// card + N ordered action cards), mirroring the web editor's `useMobile()`
/// fallback. Each card renders its params as a schema-driven form and offers a
/// per-node "Test". Run history is a collapsible list below the graph.
struct AutomationEditorView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState

    var automationId: String

    @State private var name = ""
    @State private var graph: [AppAutomationNode] = []
    @State private var nodeTypes: [AppAutomationNodeType] = []
    @State private var lists: [AppList] = []
    @State private var folders: [AppFolder] = []
    @State private var runs: [AppAutomationRun] = []
    @State private var testResults: [String: AppAutomationRun] = [:]
    @State private var loading = true
    @State private var saving = false
    @State private var showAddAction = false
    @State private var dirty = false

    private var triggerTypes: [AppAutomationNodeType] { nodeTypes.filter { $0.isTrigger } }
    private var actionTypes: [AppAutomationNodeType] { nodeTypes.filter { !$0.isTrigger } }

    var body: some View {
        ScrollView {
            if loading {
                ProgressView().padding(.top, 60)
            } else {
                VStack(spacing: 14) {
                    TextField("Automation name", text: $name)
                        .font(.system(size: 18, weight: .bold))
                        .padding(.horizontal, 16)
                        .onChange(of: name) { _, _ in dirty = true }

                    triggerCard

                    ForEach(Array(graph.dropFirst().enumerated()), id: \.element.id) { offset, _ in
                        actionCard(graphIndex: offset + 1)
                    }

                    Button { showAddAction = true } label: {
                        Label("Add Action", systemImage: "plus.circle.fill").font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.top, 2)

                    if !runs.isEmpty { runHistorySection }
                }
                .padding(.vertical, 12)
                .padding(.bottom, 60)
            }
        }
        .background(SCColor.page)
        .navigationTitle("Edit Automation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { Task { await save() } }.disabled(saving || !dirty)
            }
        }
        .confirmationDialog("Add Action", isPresented: $showAddAction, titleVisibility: .visible) {
            ForEach(actionTypes) { type in
                Button(type.label) { addAction(type: type.id) }
            }
            if actionTypes.isEmpty {
                Button("Action") { addAction(type: "action") }
            }
        }
        .task { await load() }
    }

    // MARK: cards

    private var triggerCard: some View {
        let node = graph.first
        return card(accent: SCColor.primary) {
            HStack {
                Label("TRIGGER", systemImage: "bolt.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(SCColor.primary)
                Spacer()
            }
            Picker("When…", selection: Binding(
                get: { node?.type ?? "" },
                set: { newType in setTriggerType(newType) }
            )) {
                Text("Choose a trigger…").tag("")
                ForEach(triggerOptions, id: \.self) { opt in
                    Text(triggerLabel(opt)).tag(opt)
                }
            }
            if let node, !node.type.isEmpty {
                paramForm(graphIndex: 0)
                testRow(node: node)
            }
        }
    }

    private func actionCard(graphIndex: Int) -> some View {
        let node = graph[graphIndex]
        return card(accent: Color(hex: "#f59e0b")) {
            HStack {
                Label(nodeTypeLabel(node.type).uppercased(), systemImage: "arrow.turn.down.right")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "#f59e0b"))
                Spacer()
                Menu {
                    if graphIndex > 1 { Button("Move Up", systemImage: "arrow.up") { move(graphIndex, by: -1) } }
                    if graphIndex < graph.count - 1 { Button("Move Down", systemImage: "arrow.down") { move(graphIndex, by: 1) } }
                    Button("Remove", systemImage: "trash", role: .destructive) { removeNode(graphIndex) }
                } label: { Image(systemName: "ellipsis") }
            }
            paramForm(graphIndex: graphIndex)
            testRow(node: node)
        }
    }

    @ViewBuilder
    private func testRow(node: AppAutomationNode) -> some View {
        HStack {
            Button {
                Task { testResults[node.id] = await store.testAutomationNode(id: automationId, nodeId: node.id) }
            } label: {
                Label("Test", systemImage: "play.circle").font(.system(size: 12.5, weight: .semibold))
            }
            .buttonStyle(.bordered)
            Spacer()
            if let result = testResults[node.id] {
                Text(result.status)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(statusColor(result.status))
            }
        }
        if let result = testResults[node.id], let last = result.steps.last {
            if let error = result.error ?? last.error {
                Text(error).font(.system(size: 11.5)).foregroundStyle(SCColor.danger)
            }
            if let output = last.output {
                jsonTree(output, label: "Output")
            }
        }
    }

    // MARK: param form (schema-driven)

    @ViewBuilder
    private func paramForm(graphIndex: Int) -> some View {
        let node = graph[graphIndex]
        let schema = nodeTypes.first { $0.id == node.type }?.params ?? inferredParams(for: node)
        if schema.isEmpty {
            Text("No parameters").font(.system(size: 12)).foregroundStyle(SCColor.text4)
        } else {
            ForEach(schema, id: \.key) { param in
                paramField(graphIndex: graphIndex, param: param)
            }
        }
    }

    @ViewBuilder
    private func paramField(graphIndex: Int, param: AppAutomationNodeType.Param) -> some View {
        let label = param.label ?? param.key
        switch param.type {
        case "boolean":
            Toggle(label, isOn: boolBinding(graphIndex, param.key)).font(.system(size: 13))
        case "code":
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(SCColor.text4)
                TextEditor(text: stringBinding(graphIndex, param.key))
                    .font(.system(size: 13, design: .monospaced)).frame(minHeight: 90)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(SCColor.border, lineWidth: 0.5))
            }
        case "isListId":
            picker(label, graphIndex, param.key, options: lists.map { ($0.id, $0.name) })
        case "isFolderId":
            picker(label, graphIndex, param.key, options: folders.map { ($0.id, $0.name) })
        case "isWorkspaceId":
            picker(label, graphIndex, param.key, options: appState.workspaces.map { ($0.id, $0.name) })
        default:
            if let options = param.options, !options.isEmpty {
                picker(label, graphIndex, param.key, options: options.map { ($0, $0) })
            } else {
                labeledField(label, graphIndex, param.key)
            }
        }
    }

    private func labeledField(_ label: String, _ i: Int, _ key: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(SCColor.text4)
            TextField(label, text: stringBinding(i, key))
                .font(.system(size: 14))
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(SCColor.hover))
        }
    }

    private func picker(_ label: String, _ i: Int, _ key: String, options: [(String, String)]) -> some View {
        Picker(label, selection: stringBinding(i, key)) {
            Text("—").tag("")
            ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
        }
        .font(.system(size: 13))
    }

    // MARK: run history

    private var runHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RUN HISTORY").font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(SCColor.text4)
            ForEach(runs) { run in
                DisclosureGroup {
                    ForEach(Array(run.steps.enumerated()), id: \.offset) { _, step in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(step.type ?? "step").font(.system(size: 12, weight: .semibold))
                                Spacer()
                                if let s = step.status { Text(s).font(.system(size: 10, weight: .bold)).foregroundStyle(statusColor(s)) }
                            }
                            if let error = step.error { Text(error).font(.system(size: 11)).foregroundStyle(SCColor.danger) }
                            if let output = step.output { jsonTree(output, label: "Output") }
                        }
                        .padding(.vertical, 3)
                    }
                } label: {
                    HStack {
                        Circle().fill(statusColor(run.status)).frame(width: 8, height: 8)
                        Text(run.isTest ? "Test run" : "Run").font(.system(size: 13))
                        Spacer()
                        if let d = run.createdAt {
                            Text(d, style: .time).font(.system(size: 11)).foregroundStyle(SCColor.text4)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(SCColor.card))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(SCColor.border, lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    /// §10 — a read-only recursive JSON tree (mobile stand-in for the desktop
    /// drag-and-drop field picker).
    @ViewBuilder
    private func jsonTree(_ value: JSONValue, label: String) -> some View {
        DisclosureGroup {
            Text(value.prettyJSON)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(SCColor.text3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        } label: {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(SCColor.text4)
        }
    }

    // MARK: card chrome

    @ViewBuilder
    private func card<Content: View>(accent: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SCColor.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(accent.opacity(0.35), lineWidth: 1))
            .padding(.horizontal, 16)
    }

    // MARK: bindings + mutations

    private func stringBinding(_ i: Int, _ key: String) -> Binding<String> {
        Binding(
            get: { graph.indices.contains(i) ? (graph[i].params[key]?.displayString ?? "") : "" },
            set: { newValue in
                guard graph.indices.contains(i) else { return }
                graph[i].params[key] = .string(newValue)
                dirty = true
            }
        )
    }

    private func boolBinding(_ i: Int, _ key: String) -> Binding<Bool> {
        Binding(
            get: { graph.indices.contains(i) ? (graph[i].params[key]?.boolValue ?? false) : false },
            set: { newValue in
                guard graph.indices.contains(i) else { return }
                graph[i].params[key] = .bool(newValue)
                dirty = true
            }
        )
    }

    private var triggerOptions: [String] {
        let fromRegistry = triggerTypes.map(\.id)
        return fromRegistry.isEmpty ? ["task_completed", "list_all_completed", "task_created", "schedule"] : fromRegistry
    }

    private func triggerLabel(_ type: String) -> String {
        nodeTypes.first { $0.id == type }?.label ?? type.replacingOccurrences(of: "_", with: " ").capitalized
    }
    private func nodeTypeLabel(_ type: String) -> String {
        nodeTypes.first { $0.id == type }?.label ?? type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func inferredParams(for node: AppAutomationNode) -> [AppAutomationNodeType.Param] {
        node.params.keys.sorted().map { AppAutomationNodeType.Param(key: $0, label: nil, type: nil, options: nil) }
    }

    private func setTriggerType(_ type: String) {
        if graph.isEmpty {
            if !type.isEmpty { graph = [AppAutomationNode(type: type)] }
        } else {
            graph[0].type = type
        }
        dirty = true
    }

    private func addAction(type: String) {
        graph.append(AppAutomationNode(type: type))
        dirty = true
    }

    private func removeNode(_ index: Int) {
        guard graph.indices.contains(index) else { return }
        graph.remove(at: index)
        dirty = true
    }

    private func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard graph.indices.contains(index), graph.indices.contains(target), target >= 1 else { return }
        graph.swapAt(index, target)
        dirty = true
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "success", "ok", "completed": return SCColor.success
        case "error", "failed", "failure": return SCColor.danger
        case "running", "pending": return SCColor.warning
        default: return SCColor.text4
        }
    }

    // MARK: load / save

    private func load() async {
        async let automation = store.automation(id: automationId)
        async let types = store.automationNodeTypes()
        async let allLists = store.lists()
        async let allFolders = store.folders()
        async let history = store.automationRuns(id: automationId)
        let (a, t, l, f, r) = await (automation, types, allLists, allFolders, history)
        if let a { name = a.name; graph = a.graph }
        nodeTypes = t
        lists = l
        folders = f
        runs = r
        loading = false
    }

    private func save() async {
        saving = true
        defer { saving = false }
        _ = await store.saveAutomation(id: automationId, name: name.trimmingCharacters(in: .whitespaces), graph: graph)
        runs = await store.automationRuns(id: automationId)
        dirty = false
    }
}
