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
- Optional Zsh command highlighting and per-command output copy controls.

### Terminal integration

Enable **Install Zsh integration** in Stash settings to subtly highlight the command as you type. To capture command output and add a single **⎘** link after each completed command, choose **Install ⎘ command + output copy**. This installs the MIT-licensed [Clipcmd](https://github.com/Djain912/clipcmd) CLI at a pinned revision and builds a Stash-branded VS Code extension with compact copy controls.

The copy integration requires Node.js 20+ and npm. It updates `~/.zshrc` and installs the CLI under `~/.local`. If the VS Code `code` command is available, the installer also installs the optional VS Code extension; otherwise, native terminal support still works. Open new terminal sessions (and reload VS Code, if used) after installation. **Cmd-click** the ⎘ link to copy the command and its output. The installer downloads pinned upstream source and npm dependencies; inspect the installer and linked licenses if you prefer to review them first. Use **Remove Zsh and VS Code hooks** to disable them; the CLI and its local settings remain installed.

The CLI captures output locally in a bounded in-memory buffer; it does not send terminal output to a remote service. Terminal output may contain secrets, so avoid running this with sensitive sessions. Apple Terminal and VS Code are supported by the upstream integration. Xcode's debugger console is not a shell terminal and is not supported.

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
