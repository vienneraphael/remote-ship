#!/bin/bash

NAME=""
EMAIL=""
BASH_FUNCTIONS_URL="https://raw.githubusercontent.com/vienneraphael/remote-ship/main/bash_functions.sh"
RETRY_ATTEMPTS=3
RETRY_DELAY_SECONDS=3

append_line_if_missing() {
    local file_path="$1"
    local line="$2"

    touch "$file_path"

    if ! grep -Fqx "$line" "$file_path"; then
        echo "$line" >>"$file_path"
    fi
}

retry() {
    local attempts="$1"
    shift

    local attempt=1
    while true; do
        if "$@"; then
            return 0
        fi

        if [ "$attempt" -ge "$attempts" ]; then
            return 1
        fi

        echo "Retry $attempt/$attempts failed. Retrying in ${RETRY_DELAY_SECONDS}s..."
        sleep "$RETRY_DELAY_SECONDS"
        attempt=$((attempt + 1))
    done
}

while getopts "n:e:" opt; do
    case "$opt" in
        n) NAME="$OPTARG" ;;
        e) EMAIL="$OPTARG" ;;
        *) echo "Usage: $0 -n 'Name' -e 'email'"; exit 1 ;;
    esac
done

if [ -z "$NAME" ] || [ -z "$EMAIL" ]; then
    echo "Error: All flags (-n, -e) are mandatory."
    echo "Usage: $0 -n 'Name' -e 'email'"
    exit 1
fi

retry "$RETRY_ATTEMPTS" sudo apt-get update || {
    echo "Error: Failed to update apt package lists after $RETRY_ATTEMPTS attempts."
    exit 1
}

git config --global user.name "$NAME"
git config --global user.email "$EMAIL"
git config --global push.autoSetupRemote true

ssh-keygen -t ed25519 -C "raspberry-pi" -f "$HOME/.ssh/id_ed25519" -N ""

retry "$RETRY_ATTEMPTS" sudo apt install -y bubblewrap gh npm tmux || {
    echo "Error: Failed to install apt packages after $RETRY_ATTEMPTS attempts."
    exit 1
}

retry "$RETRY_ATTEMPTS" bash -lc "curl -LsSf https://astral.sh/uv/install.sh | sh" || {
    echo "Error: Failed to install uv after $RETRY_ATTEMPTS attempts."
    exit 1
}

retry "$RETRY_ATTEMPTS" sudo npm i -g @bubblewrap/cli || {
    echo "Error: Failed to install @bubblewrap/cli after $RETRY_ATTEMPTS attempts."
    exit 1
}

retry "$RETRY_ATTEMPTS" bash -lc "curl -fsSL https://tailscale.com/install.sh | sh" || {
    echo "Error: Failed to install Tailscale after $RETRY_ATTEMPTS attempts."
    exit 1
}

echo "Fetching bash functions..."
retry "$RETRY_ATTEMPTS" curl -LsSf "$BASH_FUNCTIONS_URL" -o "$HOME/.bash_functions" || {
    echo "Error: Failed to download bash functions after $RETRY_ATTEMPTS attempts."
    exit 1
}

echo "Updating shell configuration..."
append_line_if_missing "$HOME/.bashrc" ""
append_line_if_missing "$HOME/.bashrc" "# Load remote-ship helpers"
append_line_if_missing "$HOME/.bashrc" "if [ -f ~/.bash_functions ]; then . ~/.bash_functions; fi"
append_line_if_missing "$HOME/.tmux.conf" "set -g mouse on"

mkdir -p "$HOME/worktree_init"
mkdir -p "$HOME/worktrees"

echo "------------------------------------"
echo "Setup Complete!"
echo "Git Name:   $(git config --global user.name)"
echo "Init Path:  $HOME/worktree_init"
echo "------------------------------------"

exec $SHELL
