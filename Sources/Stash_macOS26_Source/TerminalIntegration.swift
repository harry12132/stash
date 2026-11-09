import Foundation

enum TerminalColor: String, CaseIterable, Identifiable {
    case defaultColor = "default"
    case red
    case green
    case yellow
    case blue
    case magenta
    case cyan
    case white

    var id: String { rawValue }
    var title: String { self == .defaultColor ? "Default" : rawValue.capitalized }
}

@MainActor
final class TerminalIntegrationManager: ObservableObject {
    @Published private(set) var errorMessage: String?
    @Published private(set) var infoMessage: String?
    @Published var promptColor: TerminalColor {
        didSet { updateColorSettings() }
    }
    @Published var commandColor: TerminalColor {
        didSet { updateColorSettings() }
    }

    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    private let defaults = UserDefaults.standard

    init() {
        promptColor = TerminalColor(
            rawValue: UserDefaults.standard.string(forKey: "terminalPromptColor") ?? ""
        ) ?? .cyan
        commandColor = TerminalColor(
            rawValue: UserDefaults.standard.string(forKey: "terminalCommandColor") ?? ""
        ) ?? .yellow
        updateColorSettings()
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

    private static let legacyIntegrationScript = #"""
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

    private static let integrationScriptTemplate = #"""
    # >>> Stash terminal integration v2 >>>
    if [[ -o interactive && -z ${_STASH_TERMINAL_INTEGRATION_LOADED-} ]]; then
      typeset -g _STASH_TERMINAL_INTEGRATION_LOADED=1
      autoload -Uz add-zle-hook-widget add-zsh-hook

      typeset -g _stash_terminal_highlight_entry=''
      typeset -g _stash_terminal_command_color='@COMMAND_COLOR@'
      function _stash_terminal_highlight_input() {
        local entry
        local -a remaining
        for entry in "${region_highlight[@]}"; do
          [[ $entry == $_stash_terminal_highlight_entry ]] || remaining+=("$entry")
        done
        region_highlight=("${remaining[@]}")
        _stash_terminal_highlight_entry=''
        if [[ -n $BUFFER ]]; then
          _stash_terminal_highlight_entry="0 ${#BUFFER} fg=${_stash_terminal_command_color} bg=8"
          region_highlight+=("$_stash_terminal_highlight_entry")
        fi
      }

      typeset -g _stash_terminal_original_prompt="$PROMPT"
      function _stash_terminal_color_prompt() {
        local stash_prompt="$_stash_terminal_original_prompt"
        stash_prompt=${stash_prompt//\%m/%F{@PROMPT_COLOR@}%m%f}
        stash_prompt=${stash_prompt//\%M/%F{@PROMPT_COLOR@}%M%f}
        stash_prompt=${stash_prompt//\%~/%F{@PROMPT_COLOR@}%~%f}
        stash_prompt=${stash_prompt//\%1~/%F{@PROMPT_COLOR@}%1~%f}
        stash_prompt=${stash_prompt//\%2~/%F{@PROMPT_COLOR@}%2~%f}
        stash_prompt=${stash_prompt//\%3~/%F{@PROMPT_COLOR@}%3~%f}
        stash_prompt=${stash_prompt//\%4~/%F{@PROMPT_COLOR@}%4~%f}
        stash_prompt=${stash_prompt//\%5~/%F{@PROMPT_COLOR@}%5~%f}
        stash_prompt=${stash_prompt//\%6~/%F{@PROMPT_COLOR@}%6~%f}
        stash_prompt=${stash_prompt//\%7~/%F{@PROMPT_COLOR@}%7~%f}
        stash_prompt=${stash_prompt//\%8~/%F{@PROMPT_COLOR@}%8~%f}
        stash_prompt=${stash_prompt//\%9~/%F{@PROMPT_COLOR@}%9~%f}
        stash_prompt=${stash_prompt//\%d/%F{@PROMPT_COLOR@}%d%f}
        stash_prompt=${stash_prompt//\%\/%F{@PROMPT_COLOR@}%\/%f}
        stash_prompt=${stash_prompt//\%c/%F{@PROMPT_COLOR@}%c%f}
        PROMPT=$stash_prompt
      }

      add-zle-hook-widget zle-line-pre-redraw _stash_terminal_highlight_input
      add-zsh-hook precmd _stash_terminal_color_prompt
    fi
    """#

    var isInstalled: Bool {
        guard
            let startup = try? String(contentsOf: zshrcURL, encoding: .utf8),
            let script = try? String(contentsOf: integrationURL, encoding: .utf8)
        else {
            return false
        }
        return startup.contains(Self.sourceBlock)
            && (Self.isManagedIntegrationScript(script) || script == Self.legacyIntegrationScript)
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
                guard Self.isManagedIntegrationScript(existingScript) || existingScript == Self.legacyIntegrationScript else {
                    throw IntegrationError.existingScriptChanged
                }
            }
            try Self.integrationScript(promptColor: promptColor, commandColor: commandColor)
                .write(to: integrationURL, atomically: true, encoding: .utf8)

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

            if let script = try? String(contentsOf: integrationURL, encoding: .utf8),
               Self.isManagedIntegrationScript(script) || script == Self.legacyIntegrationScript {
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

    private func updateColorSettings() {
        defaults.set(promptColor.rawValue, forKey: "terminalPromptColor")
        defaults.set(commandColor.rawValue, forKey: "terminalCommandColor")
        guard isInstalled else { return }

        do {
            let script = try String(contentsOf: integrationURL, encoding: .utf8)
            guard Self.isManagedIntegrationScript(script) || script == Self.legacyIntegrationScript else {
                throw IntegrationError.existingScriptChanged
            }
            try Self.integrationScript(promptColor: promptColor, commandColor: commandColor)
                .write(to: integrationURL, atomically: true, encoding: .utf8)
            errorMessage = nil
            infoMessage = "Terminal colors saved. Open a new terminal window to apply them."
        } catch {
            errorMessage = "Could not update terminal colors: \(error.localizedDescription)"
        }
    }

    private static func isManagedIntegrationScript(_ script: String) -> Bool {
        script.contains("# >>> Stash terminal integration v2 >>>")
            || (script.contains("typeset -gi _STASH_TERMINAL_COMMAND_ACTIVE=0")
                && script.contains("function _stash_terminal_preexec()")
                && script.contains("function _stash_terminal_highlight_input()"))
    }

    private static func integrationScript(promptColor: TerminalColor, commandColor: TerminalColor) -> String {
        integrationScriptTemplate
            .replacingOccurrences(of: "@PROMPT_COLOR@", with: promptColor.rawValue)
            .replacingOccurrences(of: "@COMMAND_COLOR@", with: commandColor.rawValue)
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
