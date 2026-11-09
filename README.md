# Stash

A lightweight clipboard manager for macOS.

Stash keeps your recent clipboard items in the menu bar. Hold Option to show the floating HUD, press Option–1 through Option–5 to paste a recent item, or use Option–Space to open your clipboard library.

![Stash Screenshot](./Sources/Stash_macOS26_Source/Resources/screenshot.png)

## Install

Stash is currently installed by building it on your Mac. There is no prebuilt app download. You need macOS 15 or later, an Apple Silicon Mac, and Swift 6.3 or later (included with Xcode 26.4 or later).

1. Install Xcode 26.4 or later, or the matching Command Line Tools (VS Code, Mac Terminal, etc.)
2. Open Terminal and run:

```sh
git clone https://github.com/harry12132/stash.git
cd stash
./build-app.sh
mkdir -p ~/Applications
ditto Stash.app ~/Applications/Stash.app
open ~/Applications/Stash.app
```

This downloads the public source code and builds the app locally. The commands install Stash in your personal Applications folder; they do not require an administrator password. You can review the source and build script in this repository before running them.

### Allow keyboard shortcuts

macOS asks you to approve the permissions Stash needs. These permissions are controlled by macOS; Stash cannot enable them for you.

1. Open **System Settings → Privacy & Security → Input Monitoring** and enable Stash. You may also need to enable **Device Control & Data Access**.
2. Older macOS may have different setting names/requirments.
3. If a shortcut is not available yet, choose **Show Clipboard HUD** from the Stash menu-bar.

Stash does not need your Apple ID password, and the install steps do not turn off Gatekeeper or change your Mac's security settings.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| Hold **Option (⌥)** | Show the floating clipboard HUD |
| **Option–1** to **Option–5** | Paste one of the five most recent visible items |
| **Option–Space** | Open the clipboard library |
| **Escape** or or **Release Option (⌥)** | Dismiss the HUD |

## Features

- Search, pin, and delete clipboard items.
- Capture text and images.
- Preview image thumbnails and full-size images.
- Classify URLs, code, and text.
- Pause clipboard monitoring.
- Launch at login and control Stash from the menu bar.
- Optional Zsh prompt and command colors.

### Terminal integration

Enable **Install Zsh integration** in Stash settings to choose colors for the device name and directory in your Zsh prompt, and for commands as you type. Pick from the standard terminal colors in Settings. The integration updates `~/.config/stash/terminal-integration.zsh` and adds a source line to `~/.zshrc`; open a new Zsh terminal to apply changes. Existing prompt formats are preserved where they use standard Zsh prompt escapes for host and directory.

Stash no longer installs command-output copy links or the Clipcmd terminal integration.

## Privacy

Clipboard history is stored locally on your Mac and is not encrypted.
To protect sensitive content, pause monitoring before copying it, and clear your clipboard history when it is no longer needed.
Your clipboard data remains on your device and is never transmitted externally.

## Uninstall

1. Quit Stash from its menu-bar menu.
2. Turn off **Launch at login** in Stash settings, if enabled.
3. Move `~/Applications/Stash.app` to the Trash.
4. To remove clipboard history too, use Finder's **Go → Go to Folder…** and enter `~/Library/Application Support/Stash`. Move the Stash folder to the Trash.

Removing the app does not automatically delete its clipboard history or preferences - so delete your cliboard history in the library **(Option (⌥) + Space)**

## Build from source

To run the executable directly:

```sh
swift build -c release
swift run
```

To create the standalone app bundle:

```sh
./build-app.sh
```

Stash uses SwiftUI and AppKit with Swift Package Manager. The app bundle is ad-hoc signed for local development and is not notarized for direct binary distribution.

## License

Stash is licensed under the MIT License. See [LICENSE](LICENSE).
