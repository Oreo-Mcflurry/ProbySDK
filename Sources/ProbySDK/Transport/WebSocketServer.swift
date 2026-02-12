import Foundation
import Network

/// Connection state of the WebSocket server
public enum ConnectionState: Sendable {
    case waiting
    case connected(String)
    case disconnected
}

/// NWListener-based WebSocket server. The SDK acts as server; Desktop viewer connects as client.
final class WebSocketServer {
    private var listener: NWListener?
    private var connections: [String: NWConnection] = [:]
    private var authenticatedConnections: Set<String> = []
    private let queue = DispatchQueue(label: "com.proby.ws", qos: .utility)
    private let port: UInt16
    private let codec = MessageCodec()

    var onConnectionChanged: ((ConnectionState) -> Void)?
    var onCommandReceived: ((ViewerCommand) -> Void)?
    var onViewerAuthenticated: ((String) -> Void)?

    var pairingManager: PairingManager?

    private var handshakeProvider: (() -> Handshake)?

    init(port: UInt16 = 9394) {
        self.port = port
    }

    // MARK: - Public API

    func start(handshakeProvider: @escaping () -> Handshake) throws {
        self.handshakeProvider = handshakeProvider

        let params = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        let nwPort: NWEndpoint.Port
        if port == 0 {
            nwPort = .any
        } else {
            guard let p = NWEndpoint.Port(rawValue: port) else {
                throw WebSocketServerError.invalidPort(port)
            }
            nwPort = p
        }

        let listener = try NWListener(using: params, on: nwPort)
        self.listener = listener

        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let port = self?.listener?.port {
                    print("[ProbySDK] ✅ WebSocket server ready on port \(port)")
                }
                self?.onConnectionChanged?(.waiting)
            case .failed(let error):
                print("[ProbySDK] ❌ Listener failed: \(error)")
                self?.stop()
            default:
                print("[ProbySDK] Listener state: \(state)")
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            print("[ProbySDK] 📥 New connection from: \(connection.endpoint)")
            self?.handleNewConnection(connection)
        }

        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
        authenticatedConnections.removeAll()
        onConnectionChanged?(.disconnected)
    }

    func send(_ entries: [ProbyLogEntry]) {
        let message: WsMessage = entries.count == 1
            ? .log(entries[0])
            : .logBatch(entries)

        guard let data = codec.encode(message) else { return }

        // Only send to authenticated connections (or all if pairing not required)
        for (id, connection) in connections {
            if pairingManager == nil || authenticatedConnections.contains(id) {
                sendData(data, on: connection)
            }
        }
    }

    /// Send replay entries to a specific connection
    func sendReplay(_ entries: [ProbyLogEntry], to connectionId: String) {
        guard let connection = connections[connectionId], !entries.isEmpty else { return }
        let message = WsMessage.logReplay(entries)
        guard let data = codec.encode(message) else { return }
        sendData(data, on: connection)
    }

    /// Whether any authenticated viewer is connected
    var hasAuthenticatedViewers: Bool {
        if pairingManager == nil {
            return !connections.isEmpty
        }
        return !authenticatedConnections.isEmpty
    }

    /// Provides access to the underlying NWListener for Bonjour configuration
    var nwListener: NWListener? { listener }

    // MARK: - Internal

    private func handleNewConnection(_ connection: NWConnection) {
        let id = UUID().uuidString
        connections[id] = connection

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.onConnectionChanged?(.connected(id))
                self?.sendHandshake(to: connection)
                self?.receiveLoop(connection: connection, id: id)
            case .failed, .cancelled:
                self?.connections.removeValue(forKey: id)
                self?.authenticatedConnections.remove(id)
                if self?.connections.isEmpty == true {
                    self?.onConnectionChanged?(.waiting)
                }
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    private func receiveLoop(connection: NWConnection, id: String) {
        connection.receiveMessage { [weak self] content, _, _, error in
            guard let self else { return }

            if let error {
                print("[ProbySDK] Receive error: \(error)")
                connection.cancel()
                return
            }

            if let data = content {
                let decoded: WsMessage? = self.codec.decode(data)
                if let message = decoded {
                    self.handleMessage(message, from: id)
                }
            }

            self.receiveLoop(connection: connection, id: id)
        }
    }

    private func handleMessage(_ message: WsMessage, from connectionId: String) {
        switch message {
        case .ping:
            broadcastMessage(.pong)
        case .command(let command):
            // Only accept commands from authenticated connections
            if pairingManager == nil || authenticatedConnections.contains(connectionId) {
                onCommandReceived?(command)
            }
        case .pairingRequest(let code):
            handlePairingRequest(code: code, from: connectionId)
        default:
            break
        }
    }

    private func handlePairingRequest(code: String, from connectionId: String) {
        guard let pairingManager else {
            // Pairing not required — auto-accept
            authenticatedConnections.insert(connectionId)
            sendPairingResponse(accepted: true, reason: nil, to: connectionId)
            onViewerAuthenticated?(connectionId)
            return
        }

        let result = pairingManager.validate(code: code)
        switch result {
        case .accepted:
            authenticatedConnections.insert(connectionId)
            sendPairingResponse(accepted: true, reason: nil, to: connectionId)
            onViewerAuthenticated?(connectionId)
        case .rejected(let reason):
            sendPairingResponse(accepted: false, reason: reason, to: connectionId)
        }
    }

    private func sendPairingResponse(accepted: Bool, reason: String?, to connectionId: String) {
        guard let connection = connections[connectionId] else { return }
        let message = WsMessage.pairingResponse(accepted: accepted, reason: reason)
        guard let data = codec.encode(message) else { return }
        sendData(data, on: connection)
    }

    private func sendHandshake(to connection: NWConnection) {
        guard let handshake = handshakeProvider?() else { return }
        let message = WsMessage.handshake(handshake)
        guard let data = codec.encode(message) else { return }
        sendData(data, on: connection)
    }

    private func broadcastMessage(_ message: WsMessage) {
        guard let data = codec.encode(message) else { return }
        for (_, connection) in connections {
            sendData(data, on: connection)
        }
    }

    private func sendData(_ data: Data, on connection: NWConnection) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(
            identifier: "wsMessage",
            metadata: [metadata]
        )
        connection.send(
            content: data,
            contentContext: context,
            isComplete: true,
            completion: .contentProcessed { error in
                if let error {
                    print("[ProbySDK] Send error: \(error)")
                }
            }
        )
    }
}

// MARK: - Errors

enum WebSocketServerError: Error, LocalizedError {
    case invalidPort(UInt16)

    var errorDescription: String? {
        switch self {
        case .invalidPort(let port):
            return "Invalid port number: \(port)"
        }
    }
}
