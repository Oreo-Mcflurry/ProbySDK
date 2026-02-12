import Foundation
import Network

/// Coordinates WebSocketServer, BonjourService, PairingManager, and LogPersistence into a unified transport
final class TransportLayer {
    private var server: WebSocketServer?
    private let bonjour: BonjourService
    private var configuration: ProbyConfiguration?
    private var pairingManager: PairingManager?
    private var persistence: LogPersistence?

    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.proby.network-monitor")
    private var lastPathHasWiFi: Bool = false
    private var isRestarting: Bool = false

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

        try startServer(configuration: configuration)
        startNetworkMonitor()
    }

    /// Stops the transport layer
    func stop() {
        stopNetworkMonitor()
        stopServer()
        pairingManager = nil
        currentState = .disconnected
        configuration = nil
    }

    // MARK: - Server Lifecycle

    private func startServer(configuration: ProbyConfiguration) throws {
        let port = configuration.transport.port
        let server = WebSocketServer(port: port == 0 ? 9394 : port)
        self.server = server

        server.pairingManager = pairingManager

        server.onConnectionChanged = { [weak self] state in
            self?.currentState = state
            self?.onConnectionChanged?(state)

            if case .waiting = state, let listener = server.nwListener {
                self?.bonjour.configure(listener: listener, configuration: configuration)
            }
        }

        server.onCommandReceived = { [weak self] command in
            self?.onCommandReceived?(command)
        }

        server.onViewerAuthenticated = { [weak self] connectionId in
            self?.handleViewerAuthenticated(connectionId: connectionId)
        }

        try server.start(handshakeProvider: {
            Handshake(pairingRequired: configuration.transport.requiresPairing)
        })

        print("[ProbySDK] Server started")
    }

    private func stopServer() {
        if let server {
            bonjour.stop(listener: server.nwListener)
            server.stop()
        }
        server = nil
    }

    private func restartServer() {
        guard let configuration, !isRestarting else { return }
        isRestarting = true

        print("[ProbySDK] Network changed — restarting server...")
        stopServer()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            do {
                try self.startServer(configuration: configuration)
            } catch {
                print("[ProbySDK] Failed to restart server: \(error)")
            }
            self.isRestarting = false
        }
    }

    // MARK: - Network Monitor

    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        pathMonitor = monitor

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            let hasWiFi = path.usesInterfaceType(.wifi)
            let wasWiFi = self.lastPathHasWiFi
            self.lastPathHasWiFi = hasWiFi

            if hasWiFi && !wasWiFi {
                // Cellular → WiFi: restart to bind on new interface
                print("[ProbySDK] WiFi connected — restarting transport")
                self.restartServer()
            } else if !hasWiFi && wasWiFi {
                print("[ProbySDK] WiFi lost — logs will be persisted offline")
            }
        }

        monitor.start(queue: monitorQueue)
    }

    private func stopNetworkMonitor() {
        pathMonitor?.cancel()
        pathMonitor = nil
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
