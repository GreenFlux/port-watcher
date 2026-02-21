import SwiftUI

enum ProcessFilter: String, CaseIterable {
    case all = "All"
    case devServers = "Dev Servers"

    private static let devCommands: Set<String> = [
        "node", "python", "python3", "ruby", "php", "java", "go",
        "cargo", "deno", "bun", "next", "vite", "webpack", "uvicorn",
        "gunicorn", "flask", "django", "rails", "npm", "npx", "tsx",
        "esbuild", "parcel", "hugo", "jekyll", "caddy", "nginx",
    ]

    private static let devPortRanges: [ClosedRange<Int>] = [
        3000...3999, 4000...4999, 5000...5999, 8000...8999, 9000...9999,
    ]

    private static let systemCommands: Set<String> = [
        "ControlCenter", "rapportd", "Spotify", "Transmission",
    ]

    func matches(_ process: PortProcess) -> Bool {
        switch self {
        case .all:
            return true
        case .devServers:
            if Self.systemCommands.contains(process.displayCommand) { return false }
            let name = process.displayCommand.lowercased()
            if Self.devCommands.contains(name) { return true }
            return Self.devPortRanges.contains { $0.contains(process.port) }
        }
    }
}

enum SortColumn: String {
    case port, command, pid
}

struct ContentView: View {
    var scanner: ProcessScanner
    @State private var filter: ProcessFilter = .devServers
    @State private var searchText: String = ""
    @State private var sortColumn: SortColumn = .port
    @State private var sortAscending: Bool = true

    private var filteredProcesses: [PortProcess] {
        let filtered = scanner.visibleProcesses.filter { process in
            guard filter.matches(process) else { return false }
            guard !searchText.isEmpty else { return true }
            let query = searchText.lowercased()
            return String(process.port).contains(query)
                || process.command.lowercased().contains(query)
                || process.displayCommand.lowercased().contains(query)
                || String(process.pid).contains(query)
        }
        return filtered.sorted { a, b in
            let result: Bool
            switch sortColumn {
            case .port:
                result = a.port < b.port
            case .command:
                result = a.displayCommand.localizedCaseInsensitiveCompare(b.displayCommand) == .orderedAscending
            case .pid:
                result = a.pid < b.pid
            }
            return sortAscending ? result : !result
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            columnHeader
            Divider()
            if filteredProcesses.isEmpty {
                emptyState
            } else {
                processList
            }
            Divider()
            footerView
        }
        .font(.system(size: 11))
        .frame(width: 420, height: 400)
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .trailing) {
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                }
            }
            .frame(width: 120)
            Spacer()
            Picker("", selection: $filter) {
                ForEach(ProcessFilter.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var columnHeader: some View {
        HStack(spacing: 6) {
            sortableHeader("Port", column: .port, width: 46, alignment: .trailing)
            sortableHeader("Command", column: .command, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            sortableHeader("PID", column: .pid, width: 50, alignment: .trailing)
            Text("")
                .frame(width: 20)
            Text("Up")
                .frame(width: 36, alignment: .trailing)
            Text("")
                .frame(width: 16)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.leading, 20).padding(.trailing, 20)
        .padding(.vertical, 3)
    }

    private func sortableHeader(
        _ title: String,
        column: SortColumn,
        width: CGFloat? = nil,
        alignment: Alignment = .leading
    ) -> some View {
        Button {
            if sortColumn == column {
                sortAscending.toggle()
            } else {
                sortColumn = column
                sortAscending = true
            }
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if sortColumn == column {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: width, alignment: alignment)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No listening processes")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var processList: some View {
        List(filteredProcesses) { process in
            ProcessRow(
                process: process,
                scanner: scanner
            )
            .contextMenu {
                if process.isNew {
                    Button("Mark as Seen") {
                        scanner.markAsSeen(process)
                    }
                }
                Button("Ignore \(process.displayCommand)") {
                    scanner.ignoreProcess(command: process.displayCommand)
                }
            }
            .listRowInsets(EdgeInsets(top: 1, leading: 10, bottom: 1, trailing: 10))
        }
    }

    private var footerView: some View {
        HStack {
            if scanner.hasNewProcesses {
                Button("Acknowledge All") {
                    scanner.markAllAsSeen()
                }
                .buttonStyle(.borderless)
            }
            if !scanner.ignoredCommands.isEmpty {
                Button("Clear Ignored (\(scanner.ignoredCommands.count))") {
                    scanner.clearIgnored()
                }
                .buttonStyle(.borderless)
            }
            Spacer()
            Button { scanner.scan() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }
}

struct ProcessRow: View {
    let process: PortProcess
    let scanner: ProcessScanner
    @State private var portHovered = false

    private var rowColor: Color {
        process.isNew ? .orange : .primary
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: String(process.port))
                .monospacedDigit()
                .underline(portHovered)
                .foregroundStyle(rowColor)
                .frame(width: 46, alignment: .trailing)
                .onHover { hovering in
                    portHovered = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .onTapGesture {
                    if let url = URL(string: "http://localhost:\(process.port)") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .help("Open http://localhost:\(process.port)")

            Text(process.displayCommand)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(rowColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(verbatim: String(process.pid))
                .monospacedDigit()
                .foregroundStyle(process.isNew ? .orange : .secondary)
                .frame(width: 50, alignment: .trailing)

            Menu {
                Text(verbatim: "Port \(process.port) - \(process.displayCommand)")
                Divider()
                Button("Open in Browser") {
                    if let url = URL(string: "http://localhost:\(process.port)") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("http://localhost:\(process.port)", forType: .string)
                }
                Divider()
                Button("Kill") {
                    scanner.killProcess(process, force: false)
                }
                Button("Force Kill") {
                    scanner.killProcess(process, force: true)
                }
            } label: {
                EmptyView()
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)

            TimelineView(.periodic(from: .now, by: 30)) { _ in
                Text(verbatim: process.durationText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            Button {
                if process.cwd != "Unknown" {
                    NSWorkspace.shared.open(URL(fileURLWithPath: process.cwd))
                }
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .frame(width: 16)
            .disabled(process.cwd == "Unknown")
            .help(process.displayCwd)
        }
    }
}
