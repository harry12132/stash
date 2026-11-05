# Stash

A fast, lightweight clipboard manager for macOS.

Stash keeps recent clipboard items close at hand from the menu bar. Hold Option to show the floating HUD, use Option–1 through Option–5 for quick paste, or press Option–Space to open the full library.

## Download

**[Download Stash for macOS](https://github.com/harry12132/stash/releases/latest/download/Stash.dmg)**

Releases provide a ready-to-run `Stash.app` packaged as a macOS DMG. Stash is currently distributed as an ad-hoc signed, non-notarized app, so macOS may require you to Control-click the app and choose **Open** the first time.

If there is no published release yet, build Stash from source using the instructions below.

## Requirements

- macOS 15 or later
- Swift 6.3 or later (included with Xcode 26)
- Apple Silicon (arm64)

## Features

- Floating clipboard HUD activated by holding Option.
- Option–1 through Option–5 quick-paste shortcuts.
- Option–Space opens the clipboard library.
- Search, pin, delete, and clear clipboard history.
- Text, RTF-to-text, and image capture.
- Image thumbnails and full-size previews.
- URL, code, and text classification.
- Persistent local history with a configurable unpinned-history limit.
- Pause monitoring and exclude selected apps by bundle ID.
- Menu-bar controls and optional launch at login.
- Multi-display-aware HUD positioning.
- Keyboard-friendly native SwiftUI/AppKit interface.

Clipboard history is stored locally. It can contain sensitive information, so Stash provides pause, exclusion, persistence, and clear-history controls. History is not encrypted, and Stash does not currently detect password-manager content or automatically redact secrets.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Hold **Option** | Show the floating clipboard HUD |
| **Option–1** … **Option–5** | Paste one of the five most recent visible items |
| **Option–Space** | Open the clipboard library |
| **Escape** | Dismiss the HUD |

## Install

1. Download the latest DMG: [Download Stash for macOS](https://github.com/harry12132/stash/releases/latest/download/Stash.dmg)
2. Open the DMG and copy `Stash.app` to **Applications**.
3. Launch Stash from **Applications**.
4. If macOS warns that the app is from an unidentified developer, Control-click `Stash.app`, choose **Open**, then confirm.

Stash runs from the menu bar and does not add a Dock icon.

### Keyboard permissions

Global keyboard shortcuts require keyboard-listening access. Open **System Settings → Privacy & Security → Input Monitoring** and enable Stash. Some macOS versions expose related controls under **Device Control & Access**.

Automatic paste also requires the applicable Accessibility/device-access permission. Stash does not bypass macOS privacy controls and retries its keyboard listener after permissions are granted.

If shortcuts are not active yet, use **Show Clipboard HUD** from the Stash menu-bar menu while resolving permissions.

## Build from source

Clone the repository and run the executable:

```sh
git clone https://github.com/harry12132/stash.git
cd stash
swift build -c release
swift run
```

To create a standalone app bundle:

```sh
./build-app.sh
```

The script builds the release binary, creates `Stash.app`, copies the app resources and icon, and verifies the ad-hoc code signature.

For a local DMG:

```sh
./build-app.sh
hdiutil create -volname "Stash" -srcfolder "Stash.app" -ov -format UDZO "Stash.dmg"
```

## Development notes

Stash uses SwiftUI and AppKit with Swift Package Manager. The global shortcut listener uses CoreGraphics event taps and the macOS keyboard-listening permission APIs.

The clipboard implementation currently stores text history metadata in UserDefaults and image data separately in the user's Application Support directory. Clipboard history does not preserve file URLs or full attributed formatting.

Excluded-app matching uses the frontmost app at polling time because clipboard ownership is not exposed consistently by NSPasteboard.

## Privacy

Clipboard history can contain passwords, tokens, private messages, and other sensitive data. Pause monitoring before copying sensitive material when appropriate, use app exclusions where possible, and clear history when it is no longer needed.

Stash's history is local and is not encrypted. Review the source and your local macOS permissions before using it with sensitive information.

## License

Stash is licensed under the MIT License. See [LICENSE](LICENSE).
