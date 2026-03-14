import AppKit
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var dragMonitor: Any?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let contentView = ConverterPanelView(onDismiss: { [weak self] in
            self?.closePopover()
        })
        let hostingController = NSHostingController(rootView: contentView)
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 320, height: 240)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.doc", accessibilityDescription: "DropConvert")
            button.action = #selector(togglePopover)
            button.target = self
        }

        startDragMonitoring()
    }

    @objc private func togglePopover() {
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

    deinit {
        if let monitor = dragMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
