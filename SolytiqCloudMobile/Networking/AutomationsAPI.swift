import Foundation

/// §10 — automations (`automations.ts`). Server mode only; no local persistence
/// (automations are a SIGNAL sync entity — screens refetch on a bump). The
/// graph is an ordered array of `{id, type, params}` nodes.
struct AutomationsAPI {
    let client = APIClient.shared

    // MARK: node type registry (drives the param forms)

    struct NodeTypeDTO: Decodable {
        struct ParamDTO: Decodable { var key: String; var label: String?; var type: String?; var options: [String]? }
        var type: String?
        var id: String?
        var label: String?
        var name: String?
        var category: String?
        var params: [ParamDTO]?
        var paramsSchema: [ParamDTO]?

        func toApp() -> AppAutomationNodeType {
            let typeId = type ?? id ?? "unknown"
            let schema = (params ?? paramsSchema ?? []).map {
                AppAutomationNodeType.Param(key: $0.key, label: $0.label, type: $0.type, options: $0.options)
            }
            return AppAutomationNodeType(id: typeId, label: label ?? name ?? typeId, category: category, params: schema)
        }
    }

    func nodeTypes() async throws -> [AppAutomationNodeType] {
        struct R: Decodable { var nodeTypes: [NodeTypeDTO] }
        return try await client.request("/automations/node-types", as: R.self).nodeTypes.map { $0.toApp() }
    }

    // MARK: automations CRUD

    struct NodeDTO: Codable {
        var id: String?
        var type: String
        var params: [String: JSONValue]?
        func toApp() -> AppAutomationNode {
            AppAutomationNode(id: id ?? UUID().uuidString, type: type, params: params ?? [:])
        }
    }

    struct AutomationDTO: Decodable {
        var id: IntOrString
        var name: String?
        var enabled: Bool?
        var graph: [NodeDTO]?
        func toApp() -> AppAutomation {
            AppAutomation(id: id.stringValue, name: name ?? "Automation", enabled: enabled ?? false,
                           graph: (graph ?? []).map { $0.toApp() })
        }
    }

    func list(workspaceId: String? = nil) async throws -> [AppAutomation] {
        struct R: Decodable { var automations: [AutomationDTO] }
        var q: [String: String] = [:]
        if let workspaceId { q["workspaceId"] = workspaceId }
        return try await client.request("/automations", query: q, as: R.self).automations.map { $0.toApp() }
    }

    func get(id: String) async throws -> AppAutomation {
        struct R: Decodable { var automation: AutomationDTO }
        return try await client.request("/automations/\(id)", as: R.self).automation.toApp()
    }

    struct CreateBody: Encodable { var name: String; var workspaceId: String? }
    func create(name: String, workspaceId: String?) async throws -> AppAutomation {
        struct R: Decodable { var automation: AutomationDTO }
        return try await client.request("/automations", method: "POST",
                                         body: CreateBody(name: name, workspaceId: workspaceId), as: R.self).automation.toApp()
    }

    struct UpdateBody: Encodable { var name: String?; var graph: [NodeDTO]? }
    @discardableResult
    func update(id: String, name: String?, graph: [AppAutomationNode]?) async throws -> AppAutomation {
        struct R: Decodable { var automation: AutomationDTO }
        let nodes = graph?.map { NodeDTO(id: $0.id, type: $0.type, params: $0.params) }
        return try await client.request("/automations/\(id)", method: "PUT",
                                         body: UpdateBody(name: name, graph: nodes), as: R.self).automation.toApp()
    }

    struct EnabledBody: Encodable { var enabled: Bool }
    func setEnabled(id: String, enabled: Bool) async throws {
        _ = try await client.request("/automations/\(id)/enabled", method: "PUT", body: EnabledBody(enabled: enabled), as: APIClient.EmptyResponse.self)
    }

    func delete(id: String) async throws {
        _ = try await client.request("/automations/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    // MARK: runs + per-node test

    struct RunDTO: Decodable {
        var id: IntOrString
        var status: String?
        var isTest: Bool?
        var error: String?
        var steps: [AppAutomationRun.Step]?
        var createdAt: String?
        func toApp() -> AppAutomationRun {
            AppAutomationRun(id: id.stringValue, status: status ?? "unknown", isTest: isTest ?? false,
                              error: error, steps: steps ?? [], createdAt: ServerDate.parse(createdAt))
        }
    }

    func runs(id: String) async throws -> [AppAutomationRun] {
        struct R: Decodable { var runs: [RunDTO] }
        return try await client.request("/automations/\(id)/runs", as: R.self).runs.map { $0.toApp() }
    }

    struct TestBody: Encodable { var nodeId: String }
    func test(id: String, nodeId: String) async throws -> AppAutomationRun {
        struct R: Decodable { var run: RunDTO }
        return try await client.request("/automations/\(id)/test", method: "POST",
                                         body: TestBody(nodeId: nodeId), as: R.self).run.toApp()
    }
}
