import Foundation
import Network

/// Manages Bonjour/mDNS service advertisement via NWListener
final class BonjourService {

    /// Configures Bonjour service on the given listener
    func configure(listener: NWListener, configuration: PorbyConfiguration) {
        let deviceInfo = DeviceInfo.current()

        let deviceName: String
        if configuration.transport.anonymizesDeviceName {
            deviceName = deviceInfo.model
        } else {
            deviceName = deviceInfo.name
        }

        var txtEntries: [(String, String)] = [
            ("device_name", deviceName),
            ("sdk_version", "0.1.0"),
            ("protocol", "1"),
            ("pairing_required", String(configuration.transport.requiresPairing)),
        ]

        if configuration.transport.advertisesAppName {
            txtEntries.append(("app_name", configuration.resolvedAppName))
            txtEntries.append(("app_version", AppInfo.current().version))
        }

        let txtDict = Dictionary(uniqueKeysWithValues: txtEntries)
        let txtRecord = NWTXTRecord(txtDict)

        let serviceName = configuration.transport.bonjourServiceName ?? deviceName
        listener.service = NWListener.Service(
            name: serviceName,
            type: "_porby._tcp",
            txtRecord: txtRecord
        )
    }

    /// Removes Bonjour service advertisement
    func stop(listener: NWListener?) {
        listener?.service = nil
    }
}
