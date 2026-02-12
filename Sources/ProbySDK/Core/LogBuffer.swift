import Foundation

/// Thread-safe 2-tier buffer that collects log entries and flushes them in batches.
/// Main ring buffer for all logs, plus a priority ring for error/fatal logs
/// that survives even when the main buffer overflows.
final class LogBuffer {
    private var entries: [ProbyLogEntry] = []
    private var priorityEntries: [ProbyLogEntry] = []
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private(set) var maxSize: Int
    private let priorityMaxSize: Int

    init(maxSize: Int = 1000, priorityMaxSize: Int = 100) {
        self.maxSize = maxSize
        self.priorityMaxSize = priorityMaxSize
    }

    func append(_ entry: ProbyLogEntry) {
        lock.lock(); defer { lock.unlock() }

        let isPriority = entry.level == .error || entry.level == .fatal

        // Main buffer: drop oldest non-priority if full
        if entries.count >= maxSize {
            entries.removeFirst(entries.count - maxSize + 1)
        }
        entries.append(entry)

        // Priority ring: error/fatal logs go here as well
        if isPriority {
            if priorityEntries.count >= priorityMaxSize {
                priorityEntries.removeFirst(priorityEntries.count - priorityMaxSize + 1)
            }
            priorityEntries.append(entry)
        }
    }

    func startFlushing(interval: TimeInterval = 0.1, handler: @escaping ([ProbyLogEntry]) -> Void) {
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

    /// Drains both main and priority buffers, merging and deduplicating by entry id.
    func drain() -> [ProbyLogEntry] {
        lock.lock(); defer { lock.unlock() }

        // If no priority entries, just return main buffer
        guard !priorityEntries.isEmpty else {
            let batch = entries
            entries.removeAll(keepingCapacity: true)
            return batch
        }

        // Merge: main entries + any priority entries not already in main
        var seenIds = Set<String>(entries.map(\.id))
        var merged = entries

        for pEntry in priorityEntries {
            if !seenIds.contains(pEntry.id) {
                merged.append(pEntry)
                seenIds.insert(pEntry.id)
            }
        }

        // Sort by timestamp to maintain order
        merged.sort { $0.timestamp < $1.timestamp }

        entries.removeAll(keepingCapacity: true)
        priorityEntries.removeAll(keepingCapacity: true)
        return merged
    }

    func flush() {
        timer?.cancel()
        timer = nil
    }

    /// Reduces the max buffer size (used by memory pressure response).
    func reduceMaxSize(to newMax: Int) {
        lock.lock(); defer { lock.unlock() }
        maxSize = newMax
        if entries.count > maxSize {
            entries.removeFirst(entries.count - maxSize)
        }
    }
}
