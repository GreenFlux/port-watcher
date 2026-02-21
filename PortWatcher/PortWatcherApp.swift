import SwiftUI
import ServiceManagement

@main
struct PortWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var scanner: ProcessScanner!
    private var lastCloseTime = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        scanner = ProcessScanner()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Port Watcher")
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 400)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: ContentView(scanner: scanner)
        )

        startObservingFlash()
        startObservingNewProcesses()
    }

    // MARK: - Click handling

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if Date().timeIntervalSince(lastCloseTime) < 0.3 {
            return
        }
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            scanner.scan()
        }
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            self.lastCloseTime = Date()
        }
    }

    // MARK: - Right-click menu

    private func showMenu() {
        let menu = NSMenu()

        let launchItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About Port Watcher", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Port Watcher", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {}
    }

    @objc private func showAbout() {
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center

        let credits = NSMutableAttributedString(
            string: "A lightweight menu bar app that monitors TCP listening processes.\n\n",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .paragraphStyle: centered]
        )
        let repoLink = NSMutableAttributedString(
            string: "GitHub",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .link: URL(string: "https://github.com/GreenFlux/port-watcher")!,
                .paragraphStyle: centered,
            ]
        )
        credits.append(repoLink)
        credits.append(NSAttributedString(
            string: "\n\nMade by ",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .paragraphStyle: centered]
        ))
        let link = NSMutableAttributedString(
            string: "GreenFlux, LLC",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .link: URL(string: "https://greenflux.us")!,
                .paragraphStyle: centered,
            ]
        )
        credits.append(link)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Icon observation

    private func startObservingFlash() {
        withObservationTracking {
            _ = scanner.isFlashing
        } onChange: {
            Task { @MainActor [weak self] in
                self?.updateIcon()
                self?.startObservingFlash()
            }
        }
        updateIcon()
    }

    private func startObservingNewProcesses() {
        withObservationTracking {
            _ = scanner.hasNewProcesses
        } onChange: {
            Task { @MainActor [weak self] in
                self?.updateIcon()
                self?.startObservingNewProcesses()
            }
        }
        updateIcon()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let img = NSImage(systemSymbolName: "network", accessibilityDescription: "Port Watcher")!
        if scanner.hasNewProcesses {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemOrange])
            let tinted = img.withSymbolConfiguration(config)!
            tinted.isTemplate = false
            button.image = tinted
        } else if scanner.isFlashing {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemYellow])
            let tinted = img.withSymbolConfiguration(config)!
            tinted.isTemplate = false
            button.image = tinted
        } else {
            button.image = img
        }
    }
}
