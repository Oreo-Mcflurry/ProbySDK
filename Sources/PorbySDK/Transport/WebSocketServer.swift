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
    private let queue = DispatchQueue(label: "com.porby.ws", qos: .utility)
    private let port: UInt16
    private let codec = MessageCodec()

    var onConnectionChanged: ((ConnectionState) -> Void)?
    var onCommandReceived: ((ViewerCommand) -> Void)?

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
                self?.onConnectionChanged?(.waiting)
            case .failed(let error):
                print("[PorbySDK] Listener failed: \(error)")
                self?.stop()
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
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
        onConnectionChanged?(.disconnected)
    }

    func send(_ entries: [PorbyLogEntry]) {
        let message: WsMessage = entries.count == 1
            ? .log(entries[0])
            : .logBatch(entries)

        guard let data = codec.encode(message) else { return }

        for (_, connection) in connections {
            sendData(data, on: connection)
        }
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
                print("[PorbySDK] Receive error: \(error)")
                connection.cancel()
                return
            }

            if let data = content {
                let decoded: WsMessage? = self.codec.decode(data)
                if let message = decoded {
                    self.handleMessage(message)
                }
            }

            self.receiveLoop(connection: connection, id: id)
        }
    }

    private func handleMessage(_ message: WsMessage) {
        switch message {
        case .ping:
            broadcastMessage(.pong)
        case .command(let command):
            onCommandReceived?(command)
        case .pairingRequest:
            // TODO: Phase 2 - pairing flow
            break
        default:
            break
        }
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
                    print("[PorbySDK] Send error: \(error)")
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
