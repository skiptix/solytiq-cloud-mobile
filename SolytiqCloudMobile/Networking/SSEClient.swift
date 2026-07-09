import Foundation

/// Minimal EventSource for the backend's `GET /api/events` stream — the
/// realtime "nudge" half of the delta-sync engine. iOS has no native
/// EventSource, so this streams the response bytes through `URLSession` and
/// assembles SSE events by hand.
///
/// Parsing note: the blank line between events is the event delimiter, and
/// `AsyncBytes.lines` silently drops blank lines — so lines are assembled
/// from raw bytes here instead.
///
/// The server heartbeats a `: ping` comment every 25s; a 70s request timeout
/// therefore detects a dead connection, and the run loop reconnects with
/// exponential backoff (reset after a successful connect).
@MainActor
final class SSEClient {
    /// Called on the main actor for every complete event (name, data).
    var onEvent: ((_ event: String, _ data: String) -> Void)?
    /// Called when the server rejects the stream's token (401) — the session
    /// was revoked; reconnecting won't help.
    var onAuthRejected: (() -> Void)?

    private var loopTask: Task<Void, Never>?
    private let session: URLSession

    nonisolated init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 70          // > 2 heartbeat intervals
        config.timeoutIntervalForResource = .infinity  // the stream is meant to live forever
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    var isConnected: Bool { loopTask != nil }

    func connect(baseURL: URL, token: String) {
        disconnect()
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("api/events"),
                                        resolvingAgainstBaseURL: false) else { return }
        comps.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = comps.url else { return }
        loopTask = Task { [weak self] in
            await self?.runLoop(url: url)
        }
    }

    func disconnect() {
        loopTask?.cancel()
        loopTask = nil
    }

    private func runLoop(url: URL) async {
        var backoff: Double = 1
        while !Task.isCancelled {
            do {
                var req = URLRequest(url: url)
                req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                let (bytes, response) = try await session.bytes(for: req)
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 401 {
                        onAuthRejected?()
                        loopTask = nil
                        return
                    }
                    guard http.statusCode == 200 else {
                        throw URLError(.badServerResponse)
                    }
                }
                backoff = 1
                try await consume(bytes)
            } catch {
                // fall through to the backoff sleep below
            }
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            backoff = min(backoff * 2, 30)
        }
    }

    /// Reads the byte stream, splitting on newlines and dispatching one event
    /// per blank-line delimiter, per the SSE wire format.
    private func consume(_ bytes: URLSession.AsyncBytes) async throws {
        var lineBuf: [UInt8] = []
        var eventName = "message"
        var dataLines: [String] = []

        func finishLine() {
            let line = String(decoding: lineBuf, as: UTF8.self)
            lineBuf.removeAll(keepingCapacity: true)
            if line.isEmpty {
                if !dataLines.isEmpty {
                    onEvent?(eventName, dataLines.joined(separator: "\n"))
                }
                eventName = "message"
                dataLines = []
            } else if line.hasPrefix(":") {
                // comment / heartbeat — ignore
            } else if let value = Self.fieldValue(of: "event", in: line) {
                eventName = value
            } else if let value = Self.fieldValue(of: "data", in: line) {
                dataLines.append(value)
            }
        }

        for try await byte in bytes {
            if byte == UInt8(ascii: "\n") {
                finishLine()
            } else if byte != UInt8(ascii: "\r") {
                lineBuf.append(byte)
            }
            if Task.isCancelled { return }
        }
    }

    /// `"data: {...}"` → `"{...}"` (one optional space after the colon, per spec).
    nonisolated static func fieldValue(of field: String, in line: String) -> String? {
        guard line.hasPrefix("\(field):") else { return nil }
        var value = String(line.dropFirst(field.count + 1))
        if value.hasPrefix(" ") { value.removeFirst() }
        return value
    }
}
