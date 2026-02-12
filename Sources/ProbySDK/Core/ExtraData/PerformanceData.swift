import Foundation

/// Structured data for performance metric logs
public struct PerformanceData: Codable, Sendable, Hashable {
    public let cpuUsage: Double
    public let memoryUsageMb: Double
    public let fps: Double?
    public let diskReadBytes: UInt64?
    public let diskWriteBytes: UInt64?

    public init(
        cpuUsage: Double,
        memoryUsageMb: Double,
        fps: Double? = nil,
        diskReadBytes: UInt64? = nil,
        diskWriteBytes: UInt64? = nil
    ) {
        self.cpuUsage = cpuUsage
        self.memoryUsageMb = memoryUsageMb
        self.fps = fps
        self.diskReadBytes = diskReadBytes
        self.diskWriteBytes = diskWriteBytes
    }
}
