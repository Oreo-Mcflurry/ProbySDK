import Foundation

/// Coordinates WebSocketServer, BonjourService, PairingManager, and LogPersistence into a unified transport
final class TransportLayer {
    private var server: WebSocketServer?
    private let bonjour: BonjourService
    private var configuration: ProbyConfiguration?
    private var pairingManager: PairingManager?
    private var persistence: LogPersistence?

    var isConnected: Bool {
        if case .connected = currentState {
            return true
        }
        return false
    }

    /// Whether any authenticated viewer is connected and ready to receive logs
    var hasActiveViewers: Bool {
        server?.hasAuthenticatedViewers ?? false
    }

    private var currentState: ConnectionState = .disconnected

    var onConnectionChanged: ((ConnectionState) -> Void)?
    var onCommandReceived: ((ViewerCommand) -> Void)?

    init() {
        self.bonjour = BonjourService()
    }

    /// Starts the transport layer with the given configuration
    func start(configuration: ProbyConfiguration) throws {
        self.configuration = configuration

        // Initialize persistence if enabled
        if configuration.persistence.isEnabled {
            persistence = LogPersistence(config: configuration.persistence)
        }

        // Initialize pairing manager if required
        if configuration.transport.requiresPairing {
            let manager = PairingManager(config: configuration.transport)
            _ = manager.generateCode()
            pairingManager = manager
        }

        let port = configuration.transport.port
        let server = WebSocketServer(port: port == 0 ? 9394 : port)
        self.server = server

        // Wire up pairing manager
        server.pairingManager = pairingManager

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

        // On viewer authenticated: replay stored logs if enabled
        server.onViewerAuthenticated = { [weak self] connectionId in
            self?.handleViewerAuthenticated(connectionId: connectionId)
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
        pairingManager = nil
        currentState = .disconnected
        configuration = nil
    }

    /// Sends log entries to all connected viewers, or persists offline if no viewers
    func send(_ entries: [ProbyLogEntry]) {
        if hasActiveViewers {
            server?.send(entries)
        } else {
            // No authenticated viewers — persist entries offline
            persistence?.save(entries)
        }
    }

    /// Emergency persist — synchronous, used by crash handler
    func emergencyPersist(_ entries: [ProbyLogEntry]) {
        persistence?.emergencySave(entries)
    }

    // MARK: - Private

    private func handleViewerAuthenticated(connectionId: String) {
        guard let config = configuration, config.persistence.flushesOnConnect else { return }
        guard let persistence else { return }

        let replayEntries = persistence.loadForReplay()
        if !replayEntries.isEmpty {
            server?.sendReplay(replayEntries, to: connectionId)
            persistence.clearReplayedEntries()
        }
    }
}
