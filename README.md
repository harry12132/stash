# Stash

Stash is a native SwiftUI/AppKit clipboard manager for macOS. Its menu-bar item opens the clipboard library and settings; hold Option to show the floating clipboard HUD.

## Build and run

Requires macOS 15 or later and Swift 6.3 or later (included with Xcode 26).

Clone the repository and run the app from source:

```sh
git clone https://github.com/harry12132/stash.git
cd stash
swift build
swift run
```

To create a standalone `Stash.app` bundle:

```sh
./build-app.sh
```

Copy `Stash.app` into `/Applications` and launch it. This app is ad-hoc signed, not notarized; macOS may require Control-clicking it and choosing **Open** the first time.

## Install and grant permissions

1. Launch Stash from Applications and approve the macOS first-open warning if shown.
2. Open **System Settings → Privacy & Security → Input Monitoring** (some macOS versions show related controls under **Device Control & Access**) and enable keyboard access for Stash.
3. If automatic paste is blocked, also enable the applicable Accessibility/device-access permission.
4. Quit and reopen Stash. Its menu-bar menu reports whether keyboard shortcuts are active. Use **Show Clipboard HUD** as a manual fallback.

Hold **Option** for the floating HUD, press **Option–Space** for the library, and use **Option–1** through **Option–5** to paste recent items.

For an Xcode app target, add the six source files in `Sources/Stash_macOS26_Source` and use `StashApp.swift` as the sole application entry point. Global event monitoring may need separate signing and privacy configuration when sandboxing or distributing the app.

## Permissions

Global keyboard interception needs keyboard-listening permission in System Settings → Privacy & Security. The setting's exact label can vary by macOS version. Synthetic paste may also require device or accessibility permission. Stash requests keyboard access on launch and retries its listener automatically.

The menu-bar menu shows whether keyboard shortcuts are active and includes a shortcut to keyboard access settings. The app does not bypass macOS privacy controls. If macOS initially denies the global keyboard listener, Stash retries automatically after permissions are granted. Use **Show Clipboard HUD** in the menu-bar menu while resolving permissions.

## Included

- Option-held floating HUD.
- Option–1 through Option–5 paste shortcuts.
- Option–Space expanded library.
- Native menu-bar controls for opening the library, pausing monitoring, opening settings, and quitting.
- Escape dismissal.
- Clipboard polling and duplicate promotion.
- Plain-text, RTF-to-text, and image capture.
- Image thumbnails, full-size previews, quick-paste support, and local file-backed image history.
- URL/code/text classification.
- Persistent history, configurable unpinned history limit.
- Search, pin/unpin, delete, clear pinned/unpinned/all.
- Pause monitoring and excluded bundle IDs.
- Login Item toggle.
- Multi-display-aware HUD positioning.
- Native SwiftUI materials and keyboard-friendly controls.

## Important limitations / next engineering pass

- Clipboard history stores text and rasterized image data. It does not preserve file URLs or full attributed formatting.
- Excluded-app matching uses the frontmost app at polling time; clipboard ownership is not exposed consistently by NSPasteboard.
- The Option modifier event is observed globally, but this prototype does not provide a shortcut recorder or arbitrary user-defined key combinations.
- Click-outside dismissal is a global mouse monitor and may dismiss the HUD when clicking any other app.
- The global event tap callback and Swift 6 strict-concurrency diagnostics can vary with the Xcode SDK settings. Validate on the exact Xcode/macOS combination before shipping.
- Launch-at-login requires a properly bundled, signed app.
- Text history metadata is stored in UserDefaults; image data is stored separately in the user's Application Support folder. History is local and is not encrypted.

## Privacy

Clipboard history can contain sensitive information. The app provides pause, exclusion, persistence-off, and clear-history controls. It does not currently detect password-manager content or automatically redact secrets. Treat the history as sensitive local data.
