import AppKit
import SwiftUI
import ServiceManagement

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var dragMonitor: Any?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let contentView = ConverterPanelView(onDismiss: { })
        let hostingController = NSHostingController(rootView: contentView)
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 320, height: 240)

        super.init()

        if let button = statusItem.button {
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
            updateIcon()
        }

        // Observe appearance changes to swap light/dark icon
        NSApp.addObserver(self, forKeyPath: "effectiveAppearance", options: [.new], context: nil)

        // Re-wire dismiss now that self is available
        let cv = ConverterPanelView(onDismiss: { [weak self] in self?.closePopover() })
        popover.contentViewController = NSHostingController(rootView: cv)

        startDragMonitoring()
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    // MARK: - Context menu

    private func showContextMenu() {
        let menu = NSMenu()

        let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLoginItemEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit DropConvert", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil  // remove so left-click keeps working
    }

    @objc private func toggleLoginItem() {
        do {
            if isLoginItemEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Login item error: \(error)")
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private var isLoginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    // MARK: - Popover

    private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    // MARK: - Drag monitoring

    private func startDragMonitoring() {
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            guard let self, !self.popover.isShown else { return }
            let mouse = NSEvent.mouseLocation
            guard let frame = self.statusItemFrame(), frame.contains(mouse) else { return }
            DispatchQueue.main.async { self.showPopover() }
        }
    }

    private func statusItemFrame() -> NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        let frameInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(frameInWindow)
    }

    private var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func updateIcon() {
        let resource = isDarkMode ? "menubar-icon-dark" : "menubar-icon-light"
        let image = Bundle.module.url(forResource: resource, withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "arrow.triangle.2.circlepath.doc", accessibilityDescription: "DropConvert")
        image?.size = NSSize(width: 18, height: 18)
        statusItem.button?.image = image
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "effectiveAppearance" {
            DispatchQueue.main.async { self.updateIcon() }
        }
    }

    deinit {
        NSApp.removeObserver(self, forKeyPath: "effectiveAppearance")
        if let monitor = dragMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
