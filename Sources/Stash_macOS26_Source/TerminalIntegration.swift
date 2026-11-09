import Foundation

@MainActor
final class TerminalIntegrationManager: ObservableObject {
    @Published private(set) var errorMessage: String?
    @Published private(set) var infoMessage: String?

    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser

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
      typeset -gi _STASH_TERMINAL_COMMAND_ACTIVE=0
      autoload -Uz add-zsh-hook add-zle-hook-widget

      function _stash_terminal_preexec() {
        _STASH_TERMINAL_COMMAND_ACTIVE=1
        print -rn -- $'\e]133;C\a'
      }

      function _stash_terminal_precmd() {
        local status=$?
        if (( _STASH_TERMINAL_COMMAND_ACTIVE )); then
          print -rn -- $'\e]133;D;'$status$'\a'
          _STASH_TERMINAL_COMMAND_ACTIVE=0
        fi
        print -rn -- $'\e]133;A\a'
      }

      function _stash_terminal_prompt_end() {
        print -rn -- $'\e]133;B\a'
      }

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

      add-zsh-hook preexec _stash_terminal_preexec
      add-zsh-hook precmd _stash_terminal_precmd
      add-zle-hook-widget zle-line-init _stash_terminal_prompt_end
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
                guard existingScript == Self.integrationScript else {
                    throw IntegrationError.existingScriptChanged
                }
            } else {
                try Self.integrationScript.write(to: integrationURL, atomically: true, encoding: .utf8)
            }

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

            if
                let script = try? String(contentsOf: integrationURL, encoding: .utf8),
                script == Self.integrationScript
            {
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
