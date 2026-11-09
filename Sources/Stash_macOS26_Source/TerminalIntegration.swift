import Foundation

@MainActor
final class TerminalIntegrationManager: ObservableObject {
    @Published private(set) var errorMessage: String?
    @Published private(set) var infoMessage: String?
    @Published private(set) var copyControlsErrorMessage: String?
    @Published private(set) var copyControlsInfoMessage: String?
    @Published private(set) var isInstallingCopyControls = false

    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    private var copyControlsInstaller: Process?
    private var copyControlsLogHandle: FileHandle?

    var isCopyControlsInstalled: Bool {
        fileManager.fileExists(
            atPath: homeDirectory
                .appendingPathComponent(".config/stash/clipcmd-installed")
                .path
        )
    }

    private var zshrcURL: URL {
        homeDirectory.appendingPathComponent(".zshrc")
    }

    private var integrationURL: URL {
        homeDirectory
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("stash", isDirectory: true)
            .appendingPathComponent("terminal-integration.zsh")
    }

    private static let sourceBlock = """
    # >>> Stash terminal integration >>>
    [[ -r "$HOME/.config/stash/terminal-integration.zsh" ]] && source "$HOME/.config/stash/terminal-integration.zsh"
    # <<< Stash terminal integration <<<
    """

    private static let integrationScript = #"""
    if [[ -o interactive && -z ${_STASH_TERMINAL_INTEGRATION_LOADED-} ]]; then
      typeset -g _STASH_TERMINAL_INTEGRATION_LOADED=1
      autoload -Uz add-zle-hook-widget

      typeset -g _stash_terminal_highlight_entry=''
      function _stash_terminal_highlight_input() {
        local entry
        local -a remaining
        for entry in "${region_highlight[@]}"; do
          [[ $entry == $_stash_terminal_highlight_entry ]] || remaining+=("$entry")
        done
        region_highlight=("${remaining[@]}")
        _stash_terminal_highlight_entry=''
        if [[ -n $BUFFER ]]; then
          _stash_terminal_highlight_entry="0 ${#BUFFER} bg=8"
          region_highlight+=("$_stash_terminal_highlight_entry")
        fi
      }

      add-zle-hook-widget zle-line-pre-redraw _stash_terminal_highlight_input
    fi
    """#

    var isInstalled: Bool {
        guard
            let startup = try? String(contentsOf: zshrcURL, encoding: .utf8),
            let script = try? String(contentsOf: integrationURL, encoding: .utf8)
        else {
            return false
        }
        return startup.contains(Self.sourceBlock) && script == Self.integrationScript
    }

    func install() {
        errorMessage = nil
        infoMessage = nil

        do {
            let startup = try existingStartupContents()
            let scriptDirectory = integrationURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: scriptDirectory, withIntermediateDirectories: true)

            if fileManager.fileExists(atPath: integrationURL.path) {
                let existingScript = try String(contentsOf: integrationURL, encoding: .utf8)
                guard existingScript == Self.integrationScript || Self.isLegacyIntegrationScript(existingScript) else {
                    throw IntegrationError.existingScriptChanged
                }
            }
            try Self.integrationScript.write(to: integrationURL, atomically: true, encoding: .utf8)

            if !startup.contains(Self.sourceBlock) {
                let separator = startup.isEmpty || startup.hasSuffix("\n") ? "" : "\n"
                try (startup + separator + Self.sourceBlock + "\n")
                    .write(to: zshrcURL, atomically: true, encoding: .utf8)
            }
            infoMessage = "Zsh integration installed. Open a new terminal window to enable it."
        } catch {
            errorMessage = "Could not install Zsh integration: \(error.localizedDescription)"
        }
    }

    func installCopyControls() {
        runCopyControlsScript(
            "install-copy-controls.sh",
            successMessage: "Compact ⎘ copy controls installed. Open new terminal sessions; reload VS Code if applicable."
        )
    }

    func removeCopyControls() {
        runCopyControlsScript(
            "remove-copy-controls.sh",
            successMessage: "Stash copy controls removed. Existing terminal sessions are unchanged."
        )
    }

    func remove() {
        errorMessage = nil
        infoMessage = nil

        do {
            let startup = try String(contentsOf: zshrcURL, encoding: .utf8)
            guard startup.contains(Self.sourceBlock) else {
                throw IntegrationError.sourceBlockNotFound
            }
            let updatedStartup = startup
                .replacingOccurrences(of: Self.sourceBlock + "\n", with: "")
                .replacingOccurrences(of: Self.sourceBlock, with: "")
            try updatedStartup.write(to: zshrcURL, atomically: true, encoding: .utf8)

            if let script = try? String(contentsOf: integrationURL, encoding: .utf8),
               script == Self.integrationScript || Self.isLegacyIntegrationScript(script) {
                try fileManager.removeItem(at: integrationURL)
                infoMessage = "Zsh integration removed. Existing terminal windows are unchanged."
            } else {
                infoMessage = "Startup hook removed. The modified integration script was left untouched."
            }
        } catch {
            errorMessage = "Could not remove Zsh integration: \(error.localizedDescription)"
        }
    }

    private func existingStartupContents() throws -> String {
        guard fileManager.fileExists(atPath: zshrcURL.path) else { return "" }
        return try String(contentsOf: zshrcURL, encoding: .utf8)
    }

    private static func isLegacyIntegrationScript(_ script: String) -> Bool {
        script.contains("typeset -gi _STASH_TERMINAL_COMMAND_ACTIVE=0")
            && script.contains("function _stash_terminal_preexec()")
            && script.contains("function _stash_terminal_highlight_input()")
    }

    private func runCopyControlsScript(_ name: String, successMessage: String) {
        guard !isInstallingCopyControls else { return }
        copyControlsErrorMessage = nil
        copyControlsInfoMessage = nil

        guard let scriptURL = terminalIntegrationResource(named: name) else {
            copyControlsErrorMessage = "The terminal integration installer is missing from this app bundle."
            return
        }

        do {
            let logURL = homeDirectory
                .appendingPathComponent("Library/Application Support/Stash", isDirectory: true)
                .appendingPathComponent("terminal-integration.log")
            try fileManager.createDirectory(
                at: logURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            _ = fileManager.createFile(atPath: logURL.path, contents: nil)
            let logHandle = try FileHandle(forWritingTo: logURL)
            try logHandle.truncate(atOffset: 0)
            try logHandle.seek(toOffset: 0)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptURL.path]
            process.standardOutput = logHandle
            process.standardError = logHandle
            process.terminationHandler = { [weak self] process in
                try? logHandle.close()
                Task { @MainActor [weak self] in
                    self?.finishCopyControlsScript(
                        exitCode: process.terminationStatus,
                        successMessage: successMessage,
                        logURL: logURL
                    )
                }
            }
            try process.run()
            copyControlsLogHandle = logHandle
            copyControlsInstaller = process
            isInstallingCopyControls = true
            copyControlsInfoMessage = "Installing terminal integration…"
        } catch {
            copyControlsErrorMessage = "Could not start terminal integration installer: \(error.localizedDescription)"
        }
    }

    private func finishCopyControlsScript(exitCode: Int32, successMessage: String, logURL: URL) {
        copyControlsInstaller = nil
        copyControlsLogHandle = nil
        isInstallingCopyControls = false

        guard exitCode == 0 else {
            let log = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            let details = String(log.suffix(1800)).trimmingCharacters(in: .whitespacesAndNewlines)
            copyControlsErrorMessage = details.isEmpty
                ? "Terminal integration installer failed (exit code \(exitCode))."
                : "Terminal integration installer failed:\n\(details)"
            copyControlsInfoMessage = nil
            return
        }

        copyControlsInfoMessage = successMessage
    }

    private func terminalIntegrationResource(named name: String) -> URL? {
        let appResource = Bundle.main.resourceURL?
            .appendingPathComponent("TerminalIntegration", isDirectory: true)
            .appendingPathComponent(name)
        if let appResource, fileManager.fileExists(atPath: appResource.path) {
            return appResource
        }

        return Bundle.module.url(
            forResource: name,
            withExtension: nil,
            subdirectory: "TerminalIntegration"
        )
    }

    deinit {
        copyControlsInstaller?.terminationHandler = nil
        if copyControlsInstaller?.isRunning == true {
            copyControlsInstaller?.terminate()
        }
        try? copyControlsLogHandle?.close()
    }
}

private enum IntegrationError: LocalizedError {
    case existingScriptChanged
    case sourceBlockNotFound

    var errorDescription: String? {
        switch self {
        case .existingScriptChanged:
            "The existing \(integrationFilename) was modified; it was not overwritten."
        case .sourceBlockNotFound:
            "The Stash startup hook was not found in ~/.zshrc."
        }
    }

    private var integrationFilename: String {
        "terminal-integration.zsh"
    }
}
