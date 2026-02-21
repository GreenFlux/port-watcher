import Foundation

struct PortProcess: Identifiable, Sendable {
    let id: String
    let port: Int
    let pid: Int
    let command: String
    let cwd: String
    var firstSeen: Date
    var isNew: Bool

    init(port: Int, pid: Int, command: String, cwd: String, firstSeen: Date = Date(), isNew: Bool = false) {
        self.id = "\(pid)-\(port)"
        self.port = port
        self.pid = pid
        self.command = command
        self.cwd = cwd
        self.firstSeen = firstSeen
        self.isNew = isNew
    }

    /// Key used to identify a unique command+cwd combination for the seen log
    var seenKey: String {
        "\(displayCommand)|\(cwd)"
    }

    var durationText: String {
        let elapsed = Date().timeIntervalSince(firstSeen)
        if elapsed < 60 { return "<1m" }
        let minutes = Int(elapsed / 60)
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        return "\(days)d"
    }

    var displayCommand: String {
        // For .app bundles, show the app name (handles spaces in paths)
        if let range = command.range(of: ".app/") {
            let appPath = command[..<range.lowerBound]
            if let name = appPath.split(separator: "/").last {
                return String(name)
            }
        }
        let executable = command.components(separatedBy: " ").first ?? command
        return (executable as NSString).lastPathComponent
    }

    private static let homePath = FileManager.default.homeDirectoryForCurrentUser.path

    var displayCwd: String {
        if cwd.hasPrefix(Self.homePath) {
            return "~" + cwd.dropFirst(Self.homePath.count)
        }
        return cwd
    }
}
