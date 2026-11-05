# Stash

A fast, lightweight clipboard manager for macOS.

Stash keeps recent clipboard items close at hand from the menu bar. Hold Option to show the floating HUD, use Option–1 through Option–5 for quick paste, or press Option–Space to open the full library.

## Install

Stash is not distributed as a prebuilt app: without an Apple Developer ID, a downloaded app cannot be notarized and macOS may block it. Quit any running Stash copies, then paste this whole block into Terminal. It downloads the source, builds `Stash.app` on your Mac, installs it in `~/Applications`, opens Stash, and opens the keyboard-permission settings.

```sh
bash <<'STASH_INSTALL'
set -euo pipefail

if ! command -v git >/dev/null || ! command -v swift >/dev/null; then
    echo "Install Xcode or the Xcode Command Line Tools, then run this again." >&2
    exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
git clone --depth 1 https://github.com/harry12132/stash.git "$work_dir/stash"
cd "$work_dir/stash"
./build-app.sh

install_dir="$HOME/Applications"
mkdir -p "$install_dir"
ditto "$work_dir/stash/Stash.app" "$install_dir/Stash.app"
open -a "$install_dir/Stash.app"
sleep 2
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"

printf '\nIn Input Monitoring (or Device Control & Access), enable Stash. '
printf 'Return here and press Return to open Accessibility settings.\n'
read -r
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
STASH_INSTALL
```

This builds the app locally rather than downloading a quarantined app binary, so it should avoid the downloaded-app malware warning. It does not disable Gatekeeper or grant permissions automatically; approve macOS prompts and settings yourself. If Stash does not appear in a permission list, use that pane's add button to select `~/Applications/Stash.app`. GitHub Releases do not contain a prebuilt app or DMG.

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

### Keyboard permissions

Global keyboard shortcuts require keyboard-listening access. Open **System Settings → Privacy & Security → Input Monitoring** and enable Stash. Some macOS versions expose related controls under **Device Control & Access**.

Automatic paste also requires the applicable Accessibility/device-access permission. Stash does not bypass macOS privacy controls and retries its keyboard listener after permissions are granted.

If shortcuts are not active yet, use **Show Clipboard HUD** from the Stash menu-bar menu while resolving permissions.

## Uninstall

1. If Stash is open, choose **Quit Stash** from its menu-bar menu.
2. If **Launch at login** is enabled, turn it off in Stash's settings or remove Stash under **System Settings → General → Login Items & Extensions**.
3. In `~/Applications`, move `Stash.app` to the Trash.
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

The app bundle is ad-hoc signed for local development. Direct binary distribution without Developer ID signing and Apple notarization can trigger Gatekeeper warnings.

## Development notes

Stash uses SwiftUI and AppKit with Swift Package Manager. The global shortcut listener uses CoreGraphics event taps and the macOS keyboard-listening permission APIs.

The clipboard implementation currently stores text history metadata in UserDefaults and image data separately in the user's Application Support directory. Clipboard history does not preserve file URLs or full attributed formatting.

Excluded-app matching uses the frontmost app at polling time because clipboard ownership is not exposed consistently by NSPasteboard.

## Privacy

Clipboard history can contain passwords, tokens, private messages, and other sensitive data. Pause monitoring before copying sensitive material when appropriate, use app exclusions where possible, and clear history when it is no longer needed.

Stash's history is local and is not encrypted. Review the source and your local macOS permissions before using it with sensitive information.

## License

Stash is licensed under the MIT License. See [LICENSE](LICENSE).
