import Foundation

/// Local, opt-in diagnostic journal for playback and YouTube activity.
/// Entries stay on the device until the user explicitly shares them from Settings.
enum YouTubeDiagnostics {
    private static let lock = NSLock()
    private static let storageKey = "pleer1.youtube.diagnostics.v1"
    private static let capacity = 600

    static func record(_ event: String, details: String = "") {
        lock.lock()
        defer { lock.unlock() }

        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        let cleanDetails = details
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let line = "[\(timestamp)] \(event)\(cleanDetails.isEmpty ? "" : " | " + cleanDetails)"

        var entries = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        entries.append(line)
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
        UserDefaults.standard.set(entries, forKey: storageKey)
        NSLog("Pleer1 YouTube: %@", line)
    }

    static var exportText: String {
        lock.lock()
        defer { lock.unlock() }
        let entries = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        return (["Pleer1 YouTube diagnostics", "Entries: \(entries.count)", ""] + entries)
            .joined(separator: "\n")
    }

    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
