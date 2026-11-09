#!/bin/bash
set -euo pipefail

local_clipcmd="$HOME/.local/bin/clipcmd"
zshrc="$HOME/.zshrc"

if ! command -v code >/dev/null 2>&1; then
    for candidate in \
        "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
        "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    do
        if [[ -x "$candidate" ]]; then
            export PATH="$(dirname "$candidate"):$PATH"
            break
        fi
    done
fi

if [[ -x "$local_clipcmd" ]]; then
    "$local_clipcmd" uninstall zsh
fi

if command -v code >/dev/null 2>&1; then
    code --uninstall-extension harry12132.stash-terminal-copy || true
fi

rm -f "$HOME/.config/stash/clipcmd-installed"

if [[ -f "$zshrc" ]]; then
    temporary_zshrc="$(mktemp "${zshrc}.XXXXXX")"
    if ! awk '
        $0 == "# >>> Stash clipcmd PATH >>>" { inside = 1; next }
        $0 == "# <<< Stash clipcmd PATH <<<" && inside { inside = 0; next }
        !inside { print }
        END { if (inside) exit 2 }
    ' "$zshrc" > "$temporary_zshrc"; then
        rm -f "$temporary_zshrc"
        printf 'Stash PATH block is incomplete; leaving ~/.zshrc unchanged.\n' >&2
        exit 1
    fi
    mv "$temporary_zshrc" "$zshrc"
fi

printf 'Stash Zsh and VS Code hooks removed. The clipcmd command and its user data were left intact.\n'
