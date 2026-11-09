#!/bin/bash
set -euo pipefail

readonly CLIPCMD_REVISION="d2260a04299dce5da7b39464a8d517e814ecc354"
readonly RESOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly LOCAL_BIN="$HOME/.local/bin"
readonly ZSHRC="$HOME/.zshrc"

if [[ "${1:-}" != "" && "${1:-}" != "--build-only" ]]; then
    printf 'Usage: %s [--build-only]\n' "$0" >&2
    exit 2
fi

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

fail() {
    printf 'Stash terminal integration: %s\n' "$1" >&2
    exit 1
}

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1 \
    || ! node -e 'if (Number(process.versions.node.split(".")[0]) < 20) process.exit(1)' 2>/dev/null
then
    for candidate in /opt/homebrew/bin /usr/local/bin "$LOCAL_BIN"; do
        if [[ -x "$candidate/node" && -x "$candidate/npm" ]] \
            && "$candidate/node" -e 'if (Number(process.versions.node.split(".")[0]) < 20) process.exit(1)' 2>/dev/null
        then
            export PATH="$candidate:$PATH"
            break
        fi
    done
fi

for tool in curl tar node npm patch; do
    command -v "$tool" >/dev/null 2>&1 || fail "Required command not found: $tool"
done

node -e 'if (Number(process.versions.node.split(".")[0]) < 20) process.exit(1)' \
    || fail "Node.js 20 or later is required."

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/stash-terminal.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT

archive="$temporary_directory/clipcmd.tar.gz"
source_directory="$temporary_directory/clipcmd"
mkdir -p "$source_directory"

curl --fail --location --silent --show-error \
    "https://github.com/Djain912/clipcmd/archive/${CLIPCMD_REVISION}.tar.gz" \
    --output "$archive"
tar -xzf "$archive" --strip-components=1 -C "$source_directory"
patch -d "$source_directory" -p1 < "$RESOURCE_DIR/clipcmd-stash.patch"

(
    cd "$source_directory/cli"
    npm ci --no-audit --no-fund
    if npm install-scripts --help >/dev/null 2>&1; then
        npm install-scripts approve node-pty --allow-scripts-pin
    fi
    npm rebuild node-pty
    node -e "require('node-pty')" || fail "node-pty did not install; Apple Terminal output capture cannot work."
    npm run build
    if [[ "${1:-}" == "--build-only" ]]; then
        npm test -- src/daemon/__tests__/osc8.test.ts src/cli/__tests__/shell.test.ts test/e2e/ptyShell.e2e.test.ts
    fi
    npm pkg set optionalDependencies.node-pty=1.1.0
    npm pkg delete scripts.postinstall
)

package_archive_name="$(cd "$source_directory/cli" && npm pack --pack-destination "$temporary_directory" --silent)"
package_archive="$temporary_directory/$package_archive_name"
[[ -f "$package_archive" ]] || fail "Could not create the Clipcmd CLI package."

(
    cd "$source_directory/vscode-extension"
    npm pkg set \
        name="stash-terminal-copy" \
        displayName="Stash Terminal Copy" \
        description="Compact ⎘ copy control for command output in the Stash terminal integration." \
        publisher="harry12132" \
        version="1.0.0"
    npm install --package-lock-only --ignore-scripts --no-audit --no-fund
    npm ci --no-audit --no-fund
    npm run package
    if [[ "${1:-}" == "--build-only" ]]; then
        npm run test:unit
    fi
)

if [[ "${1:-}" == "--build-only" ]]; then
    install_prefix="$temporary_directory/global-prefix"
else
    install_prefix="$HOME/.local"
fi

npm install --global --prefix "$install_prefix" "$package_archive"
global_cli_directory="$install_prefix/lib/node_modules/clipcmd"
[[ -x "$install_prefix/bin/clipcmd" ]] || fail "Clipcmd CLI was not installed."
node - "$global_cli_directory" <<'NODE'
const path = require('node:path');
const cliDirectory = process.argv[2];
require(path.join(cliDirectory, 'dist/shared/nodePty.js')).fixSpawnHelper();
const pty = require(require.resolve('node-pty', { paths: [cliDirectory] }));
const child = pty.spawn('/bin/sh', ['-c', 'printf STASH_PTY_OK'], {
    name: 'xterm',
    cols: 80,
    rows: 24,
    cwd: process.cwd(),
    env: process.env,
});
let output = '';
child.onData((data) => { output += data; });
child.onExit(({ exitCode }) => {
    if (exitCode !== 0 || !output.includes('STASH_PTY_OK')) {
        console.error('The installed node-pty could not capture a shell process.');
        process.exitCode = 1;
    }
});
NODE

if [[ "${1:-}" == "--build-only" ]]; then
    printf 'Clipcmd source patch, CLI build, global package install, PTY capture, and VS Code extension tests succeeded.\n'
    exit 0
fi

mkdir -p "$LOCAL_BIN"
if [[ ! -f "$ZSHRC" ]]; then
    touch "$ZSHRC"
fi

temporary_zshrc="$(mktemp "${ZSHRC}.XXXXXX")"
if ! awk '
    $0 == "# >>> Stash clipcmd PATH >>>" { inside = 1; next }
    $0 == "# <<< Stash clipcmd PATH <<<" && inside { inside = 0; next }
    !inside { print }
    END { if (inside) exit 2 }
' "$ZSHRC" > "$temporary_zshrc"; then
    rm -f "$temporary_zshrc"
    fail "~/.zshrc contains an incomplete Stash PATH block; it was left unchanged."
fi
{
    printf '\n'
    cat <<'STASH_CLIPCMD_PATH'
# >>> Stash clipcmd PATH >>>
export PATH="$HOME/.local/bin:$PATH"
export STASH_CLIPCMD_COMPACT_COPY=1
# <<< Stash clipcmd PATH <<<
STASH_CLIPCMD_PATH
} >> "$temporary_zshrc"
chmod "$(stat -f '%Lp' "$ZSHRC")" "$temporary_zshrc"
mv "$temporary_zshrc" "$ZSHRC"

export PATH="$LOCAL_BIN:$PATH"
clipcmd init zsh
mkdir -p "$HOME/.config/stash"
touch "$HOME/.config/stash/clipcmd-installed"
if command -v code >/dev/null 2>&1; then
    code --install-extension "$source_directory/vscode-extension/stash-terminal-copy-1.0.0.vsix" --force
else
    printf 'VS Code CLI not found; skipping the optional VS Code extension.\n'
fi

daemon_status="$(clipcmd status)"
case "$daemon_status" in
    "Daemon is running on port "*)
        clipcmd stop
        STASH_CLIPCMD_COMPACT_COPY=1 clipcmd start
        ;;
    "Daemon is not running"*)
        ;;
    *)
        fail "Could not safely restart the Clipcmd daemon: $daemon_status"
        ;;
esac

printf 'Stash terminal copy controls installed. Open new terminal sessions'
if command -v code >/dev/null 2>&1; then
    printf ' and reload VS Code'
fi
printf '.\n'
