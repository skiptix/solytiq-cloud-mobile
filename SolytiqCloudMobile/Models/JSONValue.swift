import Foundation

/// A minimal, `Codable`/`Hashable` representation of an arbitrary JSON value.
/// Used for automation node params and run step payloads, whose shapes are
/// defined server-side and vary per node type. Dependency-free (no AnyCodable).
enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let b = try? container.decode(Bool.self) { self = .bool(b); return }
        if let d = try? container.decode(Double.self) { self = .number(d); return }
        if let s = try? container.decode(String.self) { self = .string(s); return }
        if let a = try? container.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? container.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }

    /// A human-editable string form for scalar values (used by the schema-driven
    /// param editor). Objects/arrays fall back to their JSON text.
    var displayString: String {
        switch self {
        case .string(let s): return s
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return ""
        case .object, .array: return prettyJSON
        }
    }

    var boolValue: Bool { if case .bool(let b) = self { return b }; return false }

    var prettyJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self), let str = String(data: data, encoding: .utf8) else { return "" }
        return str
    }
}
