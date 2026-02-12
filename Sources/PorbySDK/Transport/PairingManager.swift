import Foundation
import Security

/// Manages 6-digit PIN authentication for viewer connections
final class PairingManager {
    private let config: PorbyConfiguration.Transport
    private var generatedCode: String?
    private var failedAttempts: Int = 0
    private var cooldownUntil: Date?

    init(config: PorbyConfiguration.Transport) {
        self.config = config
    }

    /// Generate or return the configured pairing code
    func generateCode() -> String {
        if let manual = config.pairingCode {
            generatedCode = manual
            return manual
        }
        let code = generateSecurePin()
        generatedCode = code
        print("[PorbySDK] \u{1F511} Pairing Code: \(code)")
        return code
    }

    /// Validate a pairing attempt
    func validate(code: String) -> PairingResult {
        // Check cooldown
        if let cooldownUntil, Date() < cooldownUntil {
            let remaining = Int(cooldownUntil.timeIntervalSinceNow.rounded(.up))
            return .rejected("Cooldown active. Try again in \(remaining)s")
        }

        guard code == generatedCode else {
            failedAttempts += 1
            if failedAttempts >= config.maxPairingAttempts {
                cooldownUntil = Date().addingTimeInterval(config.pairingCooldown)
                failedAttempts = 0
                return .rejected("Too many failed attempts. Cooldown \(Int(config.pairingCooldown))s")
            }
            return .rejected("Invalid code. \(config.maxPairingAttempts - failedAttempts) attempts remaining")
        }

        // Success — reset state
        failedAttempts = 0
        cooldownUntil = nil
        return .accepted
    }

    // MARK: - Secure PIN Generation

    /// Generate cryptographically secure 6-digit PIN using Security framework
    private func generateSecurePin() -> String {
        var bytes = [UInt8](repeating: 0, count: 4)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let number = (UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])) % 1_000_000
        return String(format: "%06d", number)
    }

    // MARK: - Result Type

    enum PairingResult {
        case accepted
        case rejected(String)
    }
}
