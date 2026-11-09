import SwiftUI
import AppKit
import Carbon
import ServiceManagement
import ApplicationServices

@MainActor
enum StashLogo {
    static let image: NSImage? = {
        let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("StashLogo.png"),
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/StashLogo.png"),
            executableDirectory
                .appendingPathComponent("Stash_Stash.bundle/StashLogo.png")
        ].compactMap { $0 }

        for url in candidates {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        NSLog("Stash: could not locate StashLogo.png in app resources.")
        return nil
    }()
}

@main
struct StashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRootView(manager: appDelegate.clipboardManager)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let clipboardManager = ClipboardManager()
    private var hudController: HUDWindowController?
    private var libraryController: LibraryWindowController?
    private var settingsController: SettingsWindowController?
    private var keyboardMonitor: KeyboardShortcutManager?
    private var statusItem: NSStatusItem?
    private var pauseMenuItem: NSMenuItem?
    private var keyboardStatusMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        hudController = HUDWindowController(manager: clipboardManager)
        libraryController = LibraryWindowController(manager: clipboardManager)
        settingsController = SettingsWindowController(manager: clipboardManager)
        configureStatusItem()

        hudController?.onSelect = { [weak self] item in
            self?.paste(item)
        }

        keyboardMonitor = KeyboardShortcutManager(
            onModifierChanged: { [weak self] isDown in
                if isDown {
                    self?.hudController?.show()
                } else {
                    self?.hudController?.hide()
                }
            },
            onPasteIndex: { [weak self] index in
                guard let self, let item = self.clipboardManager.item(atVisibleIndex: index) else { return }
                self.paste(item)
            },
            onOpenLibrary: { [weak self] in
                self?.hudController?.hide()
                self?.libraryController?.show()
            },
            onEscape: { [weak self] in
                self?.hudController?.hide()
            }
        )
        keyboardMonitor?.onPermissionIssue = { [weak self] message in
            self?.clipboardManager.permissionMessage = message
            self?.keyboardStatusMenuItem?.title = message == nil
                ? "Keyboard Shortcuts: Active"
                : "Keyboard Access: Needs Attention"
        }

        clipboardManager.startMonitoring()
        keyboardMonitor?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardManager.stopMonitoring()
        keyboardMonitor?.stop()
    }

    private func paste(_ item: ClipboardItem) {
        guard clipboardManager.writeToPasteboard(item) else { return }
        hudController?.hide()

        // Give the receiving application a short interval to observe the pasteboard update.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard AXIsProcessTrusted() else {
                self.clipboardManager.permissionMessage = "Enable Accessibility access to send the paste shortcut."
                return
            }

            let source = CGEventSource(stateID: .combinedSessionState)
            let keyCode: CGKeyCode = 9 // V
            guard
                let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            else { return }

            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let logo = StashLogo.image {
            logo.isTemplate = false
            logo.size = NSSize(width: 18, height: 18)
            item.button?.image = logo
            item.button?.image?.accessibilityDescription = "Stash"
        } else {
            item.button?.image = NSImage(
                systemSymbolName: "clipboard",
                accessibilityDescription: "Stash"
            )
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Open Stash", action: #selector(openLibrary), keyEquivalent: " ")
        menu.items.last?.keyEquivalentModifierMask = [.option]
        menu.addItem(withTitle: "Show Clipboard HUD", action: #selector(showHUD), keyEquivalent: "")
        let keyboardStatusItem = NSMenuItem(
            title: "Keyboard Shortcuts: Starting…",
            action: #selector(openKeyboardPermissions),
            keyEquivalent: ""
        )
        menu.addItem(keyboardStatusItem)
        keyboardStatusMenuItem = keyboardStatusItem
        menu.addItem(
            withTitle: "Keyboard Access Settings…",
            action: #selector(openKeyboardPermissions),
            keyEquivalent: ""
        )
        menu.addItem(.separator())

        let pauseItem = NSMenuItem(
            title: "Pause Monitoring",
            action: #selector(toggleMonitoring),
            keyEquivalent: ""
        )
        menu.addItem(pauseItem)
        self.pauseMenuItem = pauseItem

        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Stash", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }

        item.menu = menu
        statusItem = item
    }

    @objc private func openLibrary() {
        hudController?.hide()
        libraryController?.show()
    }

    @objc private func showHUD() {
        hudController?.show()
    }

    @objc private func openKeyboardPermissions() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            clipboardManager.permissionMessage = "Open System Settings → Privacy & Security and enable keyboard access for Stash."
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleMonitoring() {
        clipboardManager.setPaused(!clipboardManager.isMonitoringPaused)
        pauseMenuItem?.title = clipboardManager.isMonitoringPaused
            ? "Resume Monitoring"
            : "Pause Monitoring"
    }

    @objc private func openSettings() {
        settingsController?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
