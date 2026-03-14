import AppKit

NSApplication.shared.setActivationPolicy(.accessory)
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
