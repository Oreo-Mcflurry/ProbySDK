import Foundation
#if canImport(UIKit)
import UIKit
import QuartzCore
#endif

/// Periodically collects CPU usage, memory, and FPS metrics.
final class PerformanceCollector: LogCollector {
    var onLog: ((ProbyLogEntry) -> Void)?

    private let interval: TimeInterval
    private var timer: DispatchSourceTimer?

    #if canImport(UIKit)
    private var displayLink: CADisplayLink?
    private var frameCount: Int = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var currentFPS: Double = 0
    #endif

    init(interval: TimeInterval = 5.0) {
        self.interval = interval
    }

    func start() {
        #if canImport(UIKit)
        startDisplayLink()
        #endif
        startTimer()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        #if canImport(UIKit)
        stopDisplayLink()
        #endif
    }

    // MARK: - Timer

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.collectMetrics()
        }
        timer.resume()
        self.timer = timer
    }

    // MARK: - FPS (UIKit only)

    #if canImport(UIKit)
    private func startDisplayLink() {
        DispatchQueue.main.async { [weak self] in
            let link = CADisplayLink(target: DisplayLinkProxy(collector: self), selector: #selector(DisplayLinkProxy.tick(_:)))
            link.add(to: .main, forMode: .common)
            self?.displayLink = link
        }
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    fileprivate func handleDisplayLinkTick(_ displayLink: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            frameCount = 0
            return
        }

        frameCount += 1
        let elapsed = displayLink.timestamp - lastTimestamp

        if elapsed >= 1.0 {
            currentFPS = Double(frameCount) / elapsed
            frameCount = 0
            lastTimestamp = displayLink.timestamp
        }
    }
    #endif

    // MARK: - Metrics Collection

    private func collectMetrics() {
        let cpu = cpuUsage()
        let memory = memoryUsageMB()

        #if canImport(UIKit)
        let fps: Double? = currentFPS > 0 ? currentFPS : nil
        #else
        let fps: Double? = nil
        #endif

        let data = PerformanceData(
            cpuUsage: cpu,
            memoryUsageMb: memory,
            fps: fps
        )

        let entry = ProbyLogEntry(
            level: .debug,
            category: .performance,
            message: String(format: "CPU: %.1f%% | Mem: %.1fMB | FPS: %@",
                            cpu, memory, fps.map { String(format: "%.0f", $0) } ?? "N/A"),
            file: "PerformanceCollector",
            function: "collect",
            line: 0,
            extra: .performance(data)
        )

        onLog?(entry)
    }

    // MARK: - CPU Usage (Mach API)

    private func cpuUsage() -> Double {
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)

        let result = task_threads(mach_task_self_, &threadsList, &threadsCount)
        guard result == KERN_SUCCESS, let threads = threadsList else { return 0 }

        var totalUsage: Double = 0

        // Compute info count manually since THREAD_BASIC_INFO_COUNT macro is unavailable
        let threadBasicInfoCount = mach_msg_type_number_t(
            MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<natural_t>.size
        )

        for i in 0..<Int(threadsCount) {
            var info = thread_basic_info()
            var infoCount = threadBasicInfoCount

            let kr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &infoCount)
                }
            }

            if kr == KERN_SUCCESS && (info.flags & TH_FLAGS_IDLE) == 0 {
                totalUsage += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }

        // Deallocate the thread list
        let size = vm_size_t(MemoryLayout<thread_t>.size * Int(threadsCount))
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), size)

        return totalUsage
    }

    // MARK: - Memory Usage (Mach API)

    private func memoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)

        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard kr == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024 * 1024)
    }
}

// MARK: - DisplayLink Proxy (prevents retain cycle)

#if canImport(UIKit)
private class DisplayLinkProxy {
    private weak var collector: PerformanceCollector?

    init(collector: PerformanceCollector?) {
        self.collector = collector
    }

    @objc func tick(_ displayLink: CADisplayLink) {
        collector?.handleDisplayLinkTick(displayLink)
    }
}
#endif
