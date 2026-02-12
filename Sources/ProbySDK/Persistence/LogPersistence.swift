import Foundation

/// File-based offline log storage with rotation and replay support
final class LogPersistence {
    private let config: ProbyConfiguration.Persistence
    private let directory: URL
    private let queue = DispatchQueue(label: "com.proby.persistence", qos: .utility)
    private let codec: MessageCodec = MessageCodec()

    private var currentFileURL: URL?
    private var currentFileSize: Int = 0

    private static let filePrefix = "proby_log_"
    private static let fileExtension = "json"

    init(config: ProbyConfiguration.Persistence) {
        self.config = config
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.directory = base.appendingPathComponent("Proby/logs")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Save log entries to the current file
    func save(_ entries: [ProbyLogEntry]) {
        guard config.isEnabled, !entries.isEmpty else { return }
        queue.async { [weak self] in
            self?._save(entries)
        }
    }

    /// Load stored entries for replay (up to maxReplayEntries), newest first
    func loadForReplay() -> [ProbyLogEntry] {
        guard config.isEnabled else { return [] }
        return queue.sync { _loadForReplay() }
    }

    /// Clear all log files after successful replay
    func clearReplayedEntries() {
        queue.async { [weak self] in
            self?._clearAll()
        }
    }

    /// Rotate files: enforce maxFileCount, maxFileSize, maxRetentionInterval
    func rotate() {
        queue.async { [weak self] in
            self?._rotate()
        }
    }

    /// Emergency flush — synchronously writes entries (called from crash handler)
    func emergencySave(_ entries: [ProbyLogEntry]) {
        guard config.isEnabled, !entries.isEmpty else { return }
        _save(entries)
    }

    // MARK: - Internal Implementation

    private func _save(_ entries: [ProbyLogEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(entries) else { return }
        let dataSize = data.count

        // If current file would exceed maxFileSize, rotate to new file
        if let currentURL = currentFileURL,
           currentFileSize + dataSize + 1 > config.maxFileSize { // +1 for newline separator
            currentFileURL = nil
            currentFileSize = 0
        }

        let fileURL = currentFileURL ?? createNewFile()
        currentFileURL = fileURL

        // Append entries as a JSON line (one JSON array per line)
        let line = data + Data([0x0A]) // newline
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(line)
                handle.closeFile()
                currentFileSize += line.count
            }
        } else {
            try? line.write(to: fileURL)
            currentFileSize = line.count
            applyFileProtection(to: fileURL)
        }

        // Enforce rotation after write
        _rotate()
    }

    private func _loadForReplay() -> [ProbyLogEntry] {
        let files = sortedLogFiles()
        var allEntries: [ProbyLogEntry] = []

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Read files newest-first to prioritize recent logs
        for file in files.reversed() {
            guard let data = try? Data(contentsOf: file) else { continue }

            // Each line is a JSON array of ProbyLogEntry
            let lines = data.split(separator: UInt8(0x0A))
            for line in lines.reversed() {
                guard let entries = try? decoder.decode([ProbyLogEntry].self, from: Data(line)) else { continue }
                allEntries.append(contentsOf: entries.reversed())

                if allEntries.count >= config.maxReplayEntries {
                    return Array(allEntries.prefix(config.maxReplayEntries))
                }
            }
        }

        return allEntries
    }

    private func _clearAll() {
        let files = sortedLogFiles()
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
        currentFileURL = nil
        currentFileSize = 0
    }

    private func _rotate() {
        var files = sortedLogFiles()

        // Remove files older than maxRetentionInterval
        let cutoff = Date().addingTimeInterval(-config.maxRetentionInterval)
        files = files.filter { file in
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
               let modified = attrs[.modificationDate] as? Date,
               modified < cutoff {
                try? FileManager.default.removeItem(at: file)
                return false
            }
            return true
        }

        // Enforce maxFileCount — delete oldest files
        if files.count > config.maxFileCount {
            let excess = files.prefix(files.count - config.maxFileCount)
            for file in excess {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Helpers

    private func createNewFile() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let filename = "\(Self.filePrefix)\(timestamp).\(Self.fileExtension)"
        return directory.appendingPathComponent(filename)
    }

    private func sortedLogFiles() -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return contents
            .filter { $0.lastPathComponent.hasPrefix(Self.filePrefix) && $0.pathExtension == Self.fileExtension }
            .sorted { a, b in
                // Sort by filename (which includes timestamp) ascending — oldest first
                a.lastPathComponent < b.lastPathComponent
            }
    }

    private func applyFileProtection(to url: URL) {
        let protection: FileProtectionType
        switch config.fileProtection {
        case .complete:
            protection = .complete
        case .completeUntilFirstUserAuthentication:
            protection = .completeUntilFirstUserAuthentication
        }
        try? FileManager.default.setAttributes(
            [.protectionKey: protection],
            ofItemAtPath: url.path
        )
    }
}
