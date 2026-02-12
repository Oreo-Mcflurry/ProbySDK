import Foundation

/// Coordinates WebSocketServer and BonjourService into a unified transport
final class TransportLayer {
    private var server: WebSocketServer?
    private let bonjour: BonjourService
    private var configuration: PorbyConfiguration?

    var isConnected: Bool {
        if case .connected = currentState {
            return true
        }
        return false
    }

    private var currentState: ConnectionState = .disconnected

    var onConnectionChanged: ((ConnectionState) -> Void)?
    var onCommandReceived: ((ViewerCommand) -> Void)?

    init() {
        self.bonjour = BonjourService()
    }

    /// Starts the transport layer with the given configuration
    func start(configuration: PorbyConfiguration) throws {
        self.configuration = configuration

        let port = configuration.transport.port
        let server = WebSocketServer(port: port == 0 ? 9394 : port)
        self.server = server

        server.onConnectionChanged = { [weak self] state in
            self?.currentState = state
            self?.onConnectionChanged?(state)

            // Configure Bonjour once listener is ready
            if case .waiting = state, let listener = server.nwListener {
                self?.bonjour.configure(listener: listener, configuration: configuration)
            }
        }

        server.onCommandReceived = { [weak self] command in
            self?.onCommandReceived?(command)
        }

        try server.start(handshakeProvider: {
            Handshake(pairingRequired: configuration.transport.requiresPairing)
        })
    }

    /// Stops the transport layer
    func stop() {
        if let server {
            bonjour.stop(listener: server.nwListener)
            server.stop()
        }
        server = nil
        currentState = .disconnected
        configuration = nil
    }

    /// Sends log entries to all connected viewers
    func send(_ entries: [PorbyLogEntry]) {
        server?.send(entries)
    }
}
