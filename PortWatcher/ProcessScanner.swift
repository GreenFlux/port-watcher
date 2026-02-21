import Foundation
import Observation

@MainActor
@Observable
final class ProcessScanner {
    var processes: [PortProcess] = []
    var ignoredCommands: Set<String> = []
    var isFlashing = false
    var hasNewProcesses = false
    private var refreshTask: Task<Void, Never>?
    private var flashTask: Task<Void, Never>?
    private var seenKeys: Set<String> = []
    private static let refreshInterval: Duration = .seconds(5)
    private static let seenDefaultsKey = "seenProcessKeys"

    var visibleProcesses: [PortProcess] {
        processes.filter { !ignoredCommands.contains($0.displayCommand) }
    }

    init() {
        loadIgnoredCommands()
        loadSeenKeys()
        scan()
        startAutoRefresh()
    }

    func scan() {
        Task {
            await performScanAndUpdate()
        }
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.refreshInterval)
                await performScanAndUpdate()
            }
        }
    }

    func killProcess(_ process: PortProcess, force: Bool) {
        kill(Int32(process.pid), force ? SIGKILL : SIGTERM)
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await performScanAndUpdate()
        }
    }

    func ignoreProcess(command: String) {
        ignoredCommands.insert(command)
        saveIgnoredCommands()
    }

    func clearIgnored() {
        ignoredCommands.removeAll()
        saveIgnoredCommands()
    }

    // MARK: - Scanning

    private func performScanAndUpdate() async {
        let scanned = await Task.detached {
            Self.performScan()
        }.value

        // Guard against empty scan results (transient lsof failure)
        if scanned.isEmpty && !processes.isEmpty {
            return
        }

        let oldIDs = Set(processes.map(\.id))
        let newIDs = Set(scanned.map(\.id))

        if !processes.isEmpty && oldIDs != newIDs {
            triggerFlash()
        }

        // On first launch (no seen keys saved), seed with current processes
        let isFirstLoad = seenKeys.isEmpty && !UserDefaults.standard.bool(forKey: "seenKeysInitialized")
        if isFirstLoad {
            for process in scanned {
                seenKeys.insert(process.seenKey)
            }
            UserDefaults.standard.set(true, forKey: "seenKeysInitialized")
            saveSeenKeys()
            processes = scanned
            return
        }

        // Mark processes as new if their command+cwd combo hasn't been seen before
        var updated = scanned
        var anyNew = false
        for i in updated.indices {
            let key = updated[i].seenKey
            if !seenKeys.contains(key) {
                updated[i].isNew = true
                anyNew = true
            }
        }
        hasNewProcesses = anyNew

        processes = updated
    }

    /// Mark a process as acknowledged (seen) and persist
    func markAsSeen(_ process: PortProcess) {
        seenKeys.insert(process.seenKey)
        saveSeenKeys()
        // Update the in-memory process list
        if let idx = processes.firstIndex(where: { $0.id == process.id }) {
            processes[idx].isNew = false
        }
        hasNewProcesses = processes.contains { $0.isNew }
    }

    /// Mark all currently new processes as seen
    func markAllAsSeen() {
        for process in processes where process.isNew {
            seenKeys.insert(process.seenKey)
        }
        saveSeenKeys()
        for i in processes.indices {
            processes[i].isNew = false
        }
        hasNewProcesses = false
    }

    private func triggerFlash() {
        isFlashing = true
        flashTask?.cancel()
        flashTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled {
                isFlashing = false
            }
        }
    }

    nonisolated private static func performScan() -> [PortProcess] {
        let currentUser = NSUserName()
        let lsofOutput = runCommand("/usr/sbin/lsof", arguments: ["-iTCP", "-sTCP:LISTEN", "-n", "-P"])

        var seen = Set<String>()
        var pidPortPairs: [(command: String, pid: Int, port: Int)] = []

        let lines = lsofOutput.components(separatedBy: "\n").dropFirst()
        for line in lines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 10 else { continue }

            let command = String(parts[0])
            guard let pid = Int(parts[1]) else { continue }
            let user = String(parts[2])

            guard user == currentUser else { continue }

            // NAME field: e.g. "*:3000" is at parts[8], "(LISTEN)" at parts[9]
            let tcpName = String(parts[8])
            guard let colonIdx = tcpName.lastIndex(of: ":"),
                  let port = Int(tcpName[tcpName.index(after: colonIdx)...]) else { continue }

            let key = "\(pid)-\(port)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            pidPortPairs.append((command: command, pid: pid, port: port))
        }

        guard !pidPortPairs.isEmpty else { return [] }

        let pids = Array(Set(pidPortPairs.map(\.pid)))
        let processInfos = getProcessInfos(for: pids)
        let cwds = getCwds(for: pids)

        var results: [PortProcess] = []
        for pair in pidPortPairs {
            let info = processInfos[pair.pid]
            let fullCommand = info?.command ?? ""
            let cwd = cwds[pair.pid] ?? "Unknown"
            let startTime = info?.startTime ?? Date()

            results.append(PortProcess(
                port: pair.port,
                pid: pair.pid,
                command: fullCommand.isEmpty ? pair.command : fullCommand,
                cwd: cwd,
                firstSeen: startTime
            ))
        }

        return results.sorted { $0.port < $1.port }
    }

    nonisolated private static func getProcessInfos(for pids: [Int]) -> [Int: (command: String, startTime: Date)] {
        let pidList = pids.map(String.init).joined(separator: ",")
        let output = runCommand("/bin/ps", arguments: ["-p", pidList, "-o", "pid=,lstart=,command="])

        var result: [Int: (command: String, startTime: Date)] = [:]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM dd HH:mm:ss yyyy"

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            // Format: PID Day Mon DD HH:MM:SS YYYY COMMAND...
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 7, let pid = Int(parts[0]) else { continue }
            let dateStr = "\(parts[1]) \(parts[2]) \(parts[3]) \(parts[4]) \(parts[5])"
            let startTime = formatter.date(from: dateStr) ?? Date()
            let command = parts.dropFirst(6).joined(separator: " ")
            result[pid] = (command: command, startTime: startTime)
        }
        return result
    }

    nonisolated private static func getCwds(for pids: [Int]) -> [Int: String] {
        let pidList = pids.map(String.init).joined(separator: ",")
        let output = runCommand("/usr/sbin/lsof", arguments: ["-p", pidList, "-Fn", "-a", "-d", "cwd"])

        var result: [Int: String] = [:]
        var currentPid: Int?
        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("p") {
                currentPid = Int(line.dropFirst())
            } else if line.hasPrefix("n/"), let pid = currentPid {
                result[pid] = String(line.dropFirst())
            }
        }
        return result
    }

    nonisolated private static func runCommand(_ path: String, arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        do {
            try process.run()
        } catch {
            return ""
        }

        if semaphore.wait(timeout: .now() + 10) == .timedOut {
            process.terminate()
            if semaphore.wait(timeout: .now() + 1) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
            }
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Persistence

    private func loadIgnoredCommands() {
        let saved = UserDefaults.standard.array(forKey: "ignoredCommands") as? [String] ?? []
        ignoredCommands = Set(saved)
    }

    private func saveIgnoredCommands() {
        UserDefaults.standard.set(Array(ignoredCommands), forKey: "ignoredCommands")
    }

    // MARK: - Seen process log

    private func loadSeenKeys() {
        let saved = UserDefaults.standard.array(forKey: Self.seenDefaultsKey) as? [String] ?? []
        seenKeys = Set(saved)
    }

    private func saveSeenKeys() {
        if seenKeys.count > 500 {
            seenKeys = Set(Array(seenKeys).suffix(500))
        }
        UserDefaults.standard.set(Array(seenKeys), forKey: Self.seenDefaultsKey)
    }
}
