import Foundation
import Network
import AppKit

extension Notification.Name {
    static let lightsStateChange = Notification.Name("LightsStateChange")
    static let lightsGreenFlash = Notification.Name("LightsGreenFlash")
}

enum LightsState: String {
    case executing
    case permission
    case idle
    case off
}

final class StatusServer {
    private let port: NWEndpoint.Port
    private var listener: NWListener?
    private(set) var currentState: LightsState = .idle
    private let diagnosticLogURL = URL(fileURLWithPath: "/tmp/lights-status.log")

    init(port: UInt16 = 9876) {
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            params.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: .ipv4(.loopback),
                port: port
            )
            let listener = try NWListener(using: params)
            self.listener = listener
            listener.newConnectionHandler = { [weak self] conn in
                self?.handle(conn)
            }
            listener.start(queue: .global(qos: .utility))
            NSLog("[Lights] StatusServer listening on 127.0.0.1:\(port.rawValue)")
        } catch {
            NSLog("[Lights] StatusServer failed to start: \(error)")
        }
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .global(qos: .utility))
        conn.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [weak self] data, _, _, _ in
            guard let self, let data, let req = String(data: data, encoding: .utf8) else {
                conn.cancel()
                return
            }
            let path = self.parsePath(req)
            let response = self.route(path: path)
            let body = response.body
            let http = """
            HTTP/1.1 \(response.status)\r
            Content-Type: text/plain; charset=utf-8\r
            Content-Length: \(body.utf8.count)\r
            Connection: close\r
            \r
            \(body)
            """
            conn.send(content: Data(http.utf8), completion: .contentProcessed { _ in
                conn.cancel()
            })
        }
    }

    private func parsePath(_ request: String) -> String {
        let firstLine = request.split(separator: "\r\n", maxSplits: 1).first ?? ""
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return "/" }
        return String(parts[1])
    }

    private struct Response {
        let status: String
        let body: String
    }

    private func route(path: String) -> Response {
        let cleaned = path.split(separator: "?").first.map(String.init) ?? path
        NSLog("[Lights] request route=\(cleaned) current=\(currentState.rawValue)")
        appendDiagnosticLog("request route=\(cleaned) current=\(currentState.rawValue)")
        switch cleaned {
        case "/executing":
            return setState(.executing)
        case "/permission":
            return setState(.permission)
        case "/idle":
            return setState(.idle)
        case "/off":
            return setState(.off)
        case "/status":
            return Response(status: "200 OK", body: currentState.rawValue)
        case "/snapshot":
            return Response(status: "200 OK", body: snapshotPNG() ?? "error")
        case "/", "/health":
            return Response(status: "200 OK", body: "lights ok")
        default:
            return Response(status: "404 Not Found", body: "unknown route")
        }
    }

    /// Render the floating window's content view to a PNG and write to /tmp.
    /// Returns the file path on success. Used for demo / marketing capture
    /// without requiring system Screen Recording permission.
    private func snapshotPNG() -> String? {
        var resultPath: String?
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.main.async {
            defer { group.leave() }
            guard let view = NSApp.windows
                    .first(where: { $0 is FloatingWindow })?.contentView else { return }
            let bounds = view.bounds
            guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return }
            view.cacheDisplay(in: bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else { return }
            let path = "/tmp/lights-snapshot-\(Int(Date().timeIntervalSince1970 * 1000)).png"
            do {
                try data.write(to: URL(fileURLWithPath: path))
                resultPath = path
            } catch {
                NSLog("[Lights] snapshot write failed: \(error)")
            }
        }
        _ = group.wait(timeout: .now() + 1.0)
        return resultPath
    }

    private func setState(_ state: LightsState) -> Response {
        let previousState = currentState
        currentState = state
        NSLog("[Lights] state \(previousState.rawValue) -> \(state.rawValue)")
        appendDiagnosticLog("state \(previousState.rawValue) -> \(state.rawValue)")
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .lightsStateChange,
                object: nil,
                userInfo: ["state": state.rawValue]
            )
            if state == .idle && (previousState == .executing || previousState == .permission) {
                NotificationCenter.default.post(name: .lightsGreenFlash, object: nil)
            }
        }
        return Response(status: "200 OK", body: state.rawValue)
    }

    private func appendDiagnosticLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: diagnosticLogURL.path) {
            if let handle = try? FileHandle(forWritingTo: diagnosticLogURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        } else {
            try? data.write(to: diagnosticLogURL, options: .atomic)
        }
    }
}
