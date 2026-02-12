import Foundation

/// Thread-safe buffer that collects log entries and flushes them in batches
final class LogBuffer {
    private var entries: [PorbyLogEntry] = []
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private let maxSize: Int

    init(maxSize: Int = 1000) {
        self.maxSize = maxSize
    }

    func append(_ entry: PorbyLogEntry) {
        lock.lock(); defer { lock.unlock() }
        entries.append(entry)
        if entries.count > maxSize {
            entries.removeFirst(entries.count - maxSize)
        }
    }

    func startFlushing(interval: TimeInterval = 0.1, handler: @escaping ([PorbyLogEntry]) -> Void) {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let batch = self.drain()
            if !batch.isEmpty { handler(batch) }
        }
        timer.resume()
        self.timer = timer
    }

    func drain() -> [PorbyLogEntry] {
        lock.lock(); defer { lock.unlock() }
        let batch = entries
        entries.removeAll(keepingCapacity: true)
        return batch
    }

    func flush() {
        timer?.cancel()
        timer = nil
    }
}
