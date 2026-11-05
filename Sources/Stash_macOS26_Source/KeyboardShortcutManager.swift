import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class KeyboardShortcutManager {
    var onModifierChanged: ((Bool) -> Void)?
    var onPasteIndex: ((Int) -> Void)?
    var onOpenLibrary: (() -> Void)?
    var onEscape: (() -> Void)?
    var onPermissionIssue: ((String?) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMouseMonitor: Any?
    private var permissionRetryTimer: Timer?
    private var optionIsDown = false
    private var didRequestInputMonitoring = false

    init(
        onModifierChanged: @escaping (Bool) -> Void,
        onPasteIndex: @escaping (Int) -> Void,
        onOpenLibrary: @escaping () -> Void,
        onEscape: @escaping () -> Void
    ) {
        self.onModifierChanged = onModifierChanged
        self.onPasteIndex = onPasteIndex
        self.onOpenLibrary = onOpenLibrary
        self.onEscape = onEscape
    }

    func start() {
        requestRequiredPermissions()
        installEventTap()
    }

    private func requestRequiredPermissions() {
        if !CGPreflightListenEventAccess(), !didRequestInputMonitoring {
            didRequestInputMonitoring = true
            let granted = CGRequestListenEventAccess()
            NSLog("Stash: keyboard listening permission request result: \(granted).")
        }
    }

    private func installEventTap() {
        guard eventTap == nil else { return }

        let mask = (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
            | (CGEventMask(1) << CGEventType.keyDown.rawValue)

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<KeyboardShortcutManager>.fromOpaque(refcon).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    Task { @MainActor in
                        if let tap = manager.eventTap {
                            CGEvent.tapEnable(tap: tap, enable: true)
                        }
                    }
                    return Unmanaged.passUnretained(event)
                }

                if type == .flagsChanged {
                    let down = event.flags.contains(.maskAlternate)
                    Task { @MainActor in
                        if manager.optionIsDown != down {
                            manager.optionIsDown = down
                            NSLog("Stash: Option modifier changed; down: \(down).")
                            manager.onModifierChanged?(down)
                        }
                    }
                    return Unmanaged.passUnretained(event)
                }

                guard type == .keyDown else { return Unmanaged.passUnretained(event) }
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags

                if flags.contains(.maskAlternate) {
                    let mapping: [Int64: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4]
                    if let index = mapping[keyCode] {
                        Task { @MainActor in manager.onPasteIndex?(index) }
                        return nil
                    }

                    if keyCode == 49 {
                        Task { @MainActor in manager.onOpenLibrary?() }
                        return nil
                    }
                }

                if keyCode == 53 {
                    Task { @MainActor in manager.onEscape?() }
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: pointer
        ) else {
            let hasInputMonitoring = CGPreflightListenEventAccess()
            let message = hasInputMonitoring
                ? "macOS denied Stash’s global keyboard listener. Quit other Stash copies, then reopen the app from Applications."
                : "Allow Stash to monitor keyboard input in System Settings → Privacy & Security → Input Monitoring (or Device Control & Access on newer macOS). Stash retries automatically."
            NSLog(
                "Stash: keyboard event tap unavailable; keyboard listening permission: \(hasInputMonitoring). Retrying."
            )
            onPermissionIssue?(message)
            schedulePermissionRetry()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let runLoopSource else {
            CFMachPortInvalidate(tap)
            eventTap = nil
            onPermissionIssue?("Stash could not attach its keyboard listener to the main run loop.")
            schedulePermissionRetry()
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        guard CFMachPortIsValid(tap), CGEvent.tapIsEnabled(tap: tap) else {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CFMachPortInvalidate(tap)
            self.runLoopSource = nil
            self.eventTap = nil
            let message = "macOS created Stash’s keyboard listener but did not enable it. Check keyboard access in Privacy & Security."
            NSLog("Stash: created the keyboard event tap but macOS did not enable it.")
            onPermissionIssue?(message)
            schedulePermissionRetry()
            return
        }

        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil
        NSLog(
            "Stash: global keyboard shortcuts are active; keyboard listening: \(CGPreflightListenEventAccess()), Accessibility: \(AXIsProcessTrusted())."
        )
        onPermissionIssue?(nil)

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            Task { @MainActor in
                // The HUD is non-activating; clicking elsewhere dismisses it.
                self?.onModifierChanged?(false)
            }
        }
    }

    private func schedulePermissionRetry() {
        guard permissionRetryTimer == nil else { return }
        permissionRetryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.requestRequiredPermissions()
                self?.installEventTap()
            }
        }
        if let permissionRetryTimer {
            RunLoop.main.add(permissionRetryTimer, forMode: .common)
        }
    }

    func stop() {
        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        eventTap = nil
        runLoopSource = nil

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

}
