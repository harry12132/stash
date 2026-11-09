# Stash

Stash is a native macOS clipboard manager that lives in your menu bar. It keeps recent text and images available through a keyboard-driven HUD, with a searchable library for managing saved items.

![Stash Screenshot](./Sources/Stash_macOS26_Source/Resources/screenshot.png)

## Features

- **Clipboard HUD:** Hold Option (⌥) to bring up your recent clipboard items.
- **Quick paste:** Press Option–1 through Option–5 to paste one of the five most recent visible items.
- **Clipboard library:** Search, preview, pin, unpin, copy, and delete clipboard items.
- **Local history:** Keep recent text and images on your Mac.
- **Capture controls:** Pause monitoring, exclude specific applications, and clear clipboard history.
- **Configurable history:** Choose whether history persists between launches and set a limit for unpinned items.
- **Launch at login:** Optionally start Stash when you sign in.
- **Zsh integration:** Optionally colour the device name, directory, and command text in your Zsh prompt.

## Requirements

- macOS 15 or later
- Swift 6.3 or later
- Xcode or the matching Xcode Command Line Tools

Stash uses SwiftUI, AppKit, and Swift Package Manager.

## Install

Stash currently provides source code rather than a prebuilt, notarized app. Build it locally using one of the options below.

### Option 1: Clone with Git

Open Terminal and run:

```sh
git clone https://github.com/harry12132/stash.git
cd stash
./build-app.sh
mkdir -p ~/Applications
ditto Stash.app ~/Applications/Stash.app
open ~/Applications/Stash.app
```

### Option 2: Download the source ZIP

1. Download the [latest source ZIP](https://github.com/harry12132/stash/archive/refs/heads/main.zip), or choose **Code → Download ZIP** on the [repository page](https://github.com/harry12132/stash).
2. Extract the ZIP.
3. Open Terminal in the extracted `stash-main` folder and run:

```sh
./build-app.sh
mkdir -p ~/Applications
ditto Stash.app ~/Applications/Stash.app
open ~/Applications/Stash.app
```

The build script creates `Stash.app` in the repository folder. The commands above copy it to your personal Applications folder; they do not require an administrator password.

You can also check the [latest GitHub release](https://github.com/harry12132/stash/releases/latest). Releases currently contain source code, not a prebuilt app.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| Hold **Option (⌥)** | Show the floating clipboard HUD |
| **Option–1** to **Option–5** | Paste one of the five most recent visible items |
| **Option–Space** | Open the clipboard library |
| **Escape** or release **Option (⌥)** | Dismiss the HUD |

You can also open Stash from its menu-bar icon. Use **Show Clipboard HUD** if the HUD shortcut is unavailable, or **Open Stash** to browse the library.

## Settings and permissions

Open **Settings…** from the Stash menu-bar menu.

- **Clipboard:** Pause monitoring, choose whether history is saved between launches, and set the maximum number of unpinned items.
- **Privacy:** Add excluded applications by bundle identifier or clear clipboard history.
- **General:** Enable or disable launch at login.
- **Terminal:** Configure prompt and command colours, and install or remove the optional Zsh integration.

macOS controls keyboard and paste permissions. If shortcuts or automatic pasting do not work, open **System Settings → Privacy & Security** and allow Stash under the relevant permission controls, such as **Input Monitoring** or **Accessibility**, if requested. Permission labels can vary by macOS version. Quit and reopen Stash after changing permissions.

## Zsh integration

In **Settings → Terminal**, choose a colour for **Device name + directory** and a separate colour for **Command text**, then select **Install Zsh integration**. Stash adds a managed hook to `~/.zshrc` and writes its script to:

```text
~/.config/stash/terminal-integration.zsh
```

Open a new Zsh terminal for the changes to take effect. Remove the integration from Settings at any time.

The prompt colour applies to standard Zsh hostname and directory prompt escapes. Custom prompts that construct these values another way may not be recoloured. The integration changes prompt appearance; it does not capture terminal output or add terminal copy controls.

## Update

For an installation created with Git, open Terminal in the repository and run:

```sh
git pull
./build-app.sh
mkdir -p ~/Applications
ditto Stash.app ~/Applications/Stash.app
```

Quit Stash before replacing the installed app, then launch it again:

```sh
open ~/Applications/Stash.app
```

For a source ZIP installation, download and extract the latest ZIP, then run the build and install commands from the new folder.

## Privacy

Clipboard history is stored locally on your Mac. Stash does not send clipboard contents to a remote service. **Clipboard history is not encrypted.** Pause monitoring before copying sensitive information, exclude applications as needed, and clear history when it is no longer needed.

Images in saved history are stored under:

```text
~/Library/Application Support/Stash
```

## Uninstall

1. If enabled, choose **Remove Zsh integration** in Stash Settings.
2. Quit Stash from its menu-bar menu.
3. Turn off **Launch at login** in Settings if it is enabled.
4. Move `~/Applications/Stash.app` to the Trash.
5. To remove saved clipboard history and preferences, move `~/Library/Application Support/Stash` to the Trash.

## Build from source

To build and run the executable directly:

```sh
swift build -c release
swift run
```

To create the standalone app bundle:

```sh
./build-app.sh
```

The app bundle is ad-hoc signed for local development and is not notarized for direct binary distribution. macOS may show a security warning when opening an app built this way.

## License

Stash is open source and licensed under the MIT License. See [LICENSE](LICENSE).
