import SwiftUI
import AppKit

@MainActor
final class HUDWindowController {
    private var panel: NSPanel?
    private let manager: ClipboardManager
    var onSelect: ((ClipboardItem) -> Void)?

    init(manager: ClipboardManager) {
        self.manager = manager
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 376, height: 430),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.contentView = NSHostingView(rootView: HUDView(manager: manager) { [weak self] item in
            self?.onSelect?(item)
        })
        self.panel = panel
    }

    func show() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = panel.frame.size
        let x = min(max(mouse.x - size.width / 2, visible.minX + 12), visible.maxX - size.width - 12)
        let y = min(max(mouse.y - size.height / 2, visible.minY + 12), visible.maxY - size.height - 12)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }
}

@MainActor
final class LibraryWindowController {
    private var windowController: NSWindowController?
    private let manager: ClipboardManager

    init(manager: ClipboardManager) {
        self.manager = manager
    }

    func show() {
        if let windowController {
            windowController.window?.center()
            windowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Stash"
        window.minSize = NSSize(width: 560, height: 420)
        window.contentView = NSHostingView(rootView: LibraryView(manager: manager))
        let windowController = NSWindowController(window: window)
        self.windowController = windowController
        window.center()
        windowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
