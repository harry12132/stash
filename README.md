# Stash

A fast, lightweight clipboard manager for macOS.

Stash keeps recent clipboard items close at hand from the menu bar. Hold Option to show the floating HUD, use Option–1 through Option–5 for quick paste, or press Option–Space to open the full library.

## Download

**[Download the latest Stash DMG](https://github.com/harry12132/stash/releases/latest/download/Stash.dmg)**

The currently published v1.0.1 DMG is ad-hoc signed and **not notarized**; Gatekeeper may refuse to open it. Do not treat that download as install-ready. The release workflow is being updated to publish only Apple-notarized builds, with a larger app icon, Applications shortcut, and clear drag-to-install instructions.

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
4. Open Stash from Applications. A properly notarized release should open without an unidentified-developer or malware warning. If macOS reports that it cannot verify the app, do not bypass the warning; report the release version so its signature and notarization can be checked.

Stash runs from the menu bar and does not add a Dock icon.

### Keyboard permissions

Global keyboard shortcuts require keyboard-listening access. Open **System Settings → Privacy & Security → Input Monitoring** and enable Stash. Some macOS versions expose related controls under **Device Control & Access**.

Automatic paste also requires the applicable Accessibility/device-access permission. Stash does not bypass macOS privacy controls and retries its keyboard listener after permissions are granted.

If shortcuts are not active yet, use **Show Clipboard HUD** from the Stash menu-bar menu while resolving permissions.

## Uninstall

1. If Stash is open, choose **Quit Stash** from its menu-bar menu.
2. If **Launch at login** is enabled, turn it off in Stash's settings or remove Stash under **System Settings → General → Login Items & Extensions**.
3. In Applications, move `Stash.app` to the Trash. Eject the Stash disk image if it is still mounted.
4. To revoke its access, remove Stash under **System Settings → Privacy & Security → Input Monitoring** and any Accessibility/device-access permissions you granted.

Removing the app keeps your local clipboard history and preferences. To erase them too, use Finder's **Go → Go to Folder…**, enter `~/Library/Application Support/Stash`, and move the `Stash` folder to the Trash. To remove saved preferences as well, run `defaults delete com.harry.Stash` in Terminal.

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

To create a local DMG with a large app icon, an Applications shortcut, and drag-to-install instructions:

```sh
brew install create-dmg
./Packaging/build-dmg.sh
```

## Release signing and notarization

Automated releases require an Apple Developer Program membership, a **Developer ID Application** certificate exported as a password-protected `.p12`, and an Apple app-specific password. Add these repository Actions secrets under **Settings → Secrets and variables → Actions**:

- `APPLE_DEVELOPER_ID_P12`: base64-encoded contents of the exported `.p12` certificate.
- `APPLE_DEVELOPER_ID_P12_PASSWORD`: the password used to export that certificate.
- `APPLE_ID`: the Apple Account email for notarization.
- `APPLE_APP_SPECIFIC_PASSWORD`: an app-specific password for that Apple Account.
- `APPLE_TEAM_ID`: the 10-character Apple Developer Team ID.

On a Mac, copy the encoded certificate into the clipboard with `base64 -i DeveloperID.p12 | tr -d '\n' | pbcopy`, then paste it directly into the `APPLE_DEVELOPER_ID_P12` secret field. Never commit the certificate or share it in chat.

The release workflow signs the app with hardened runtime, submits both the app and DMG to Apple's notarization service, staples the tickets, and verifies Gatekeeper acceptance before publishing. Without these secrets, release creation intentionally fails rather than publishing an app that macOS will block.

## Development notes

Stash uses SwiftUI and AppKit with Swift Package Manager. The global shortcut listener uses CoreGraphics event taps and the macOS keyboard-listening permission APIs.

The clipboard implementation currently stores text history metadata in UserDefaults and image data separately in the user's Application Support directory. Clipboard history does not preserve file URLs or full attributed formatting.

Excluded-app matching uses the frontmost app at polling time because clipboard ownership is not exposed consistently by NSPasteboard.

## Privacy

Clipboard history can contain passwords, tokens, private messages, and other sensitive data. Pause monitoring before copying sensitive material when appropriate, use app exclusions where possible, and clear history when it is no longer needed.

Stash's history is local and is not encrypted. Review the source and your local macOS permissions before using it with sensitive information.

## License

Stash is licensed under the MIT License. See [LICENSE](LICENSE).
