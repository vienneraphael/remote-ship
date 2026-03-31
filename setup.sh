#!/bin/bash

NAME=""
EMAIL=""
IP=""
USER=""
BASH_FUNCTIONS_URL="https://raw.githubusercontent.com/vienneraphael/remote-ship/main/bash_functions.sh"

append_line_if_missing() {
    local file_path="$1"
    local line="$2"

    touch "$file_path"

    if ! grep -Fqx "$line" "$file_path"; then
        echo "$line" >>"$file_path"
    fi
}

while getopts "n:e:i:u:" opt; do
    case "$opt" in
        n) NAME="$OPTARG" ;;
        e) EMAIL="$OPTARG" ;;
        i) IP="$OPTARG" ;;
        u) USER="$OPTARG" ;;
        *) echo "Usage: $0 -n 'Name' -e 'email' -i 'IP' -u 'user'"; exit 1 ;;
    esac
done

if [ -z "$NAME" ] || [ -z "$EMAIL" ] || [ -z "$IP" ] || [ -z "$USER" ]; then
    echo "Error: All flags (-n, -e, -i, -u) are mandatory."
    echo "Usage: $0 -n 'Name' -e 'email' -i '192.168.1.1' -u 'pi'"
    exit 1
fi

sudo apt-get update && sudo apt-get upgrade -y

git config --global user.name "$NAME"
git config --global user.email "$EMAIL"
git config --global push.autoSetupRemote true

ssh-keygen -t ed25519 -C "raspberry-pi" -f "$HOME/.ssh/id_ed25519" -N ""

sudo apt install -y gh npm tmux
curl -LsSf https://astral.sh/uv/install.sh | sh
sudo npm i -g @bubblewrap/cli
sudo npm i -g @openai/codex
curl -fsSL https://tailscale.com/install.sh | sh

echo "Fetching bash functions..."
curl -LsSf "$BASH_FUNCTIONS_URL" -o "$HOME/.bash_functions"

echo "Updating shell configuration..."
append_line_if_missing "$HOME/.bashrc" ""
append_line_if_missing "$HOME/.bashrc" "# Load remote-ship helpers"
append_line_if_missing "$HOME/.bashrc" "if [ -f ~/.bash_functions ]; then . ~/.bash_functions; fi"
append_line_if_missing "$HOME/.bashrc" "alias connect='ssh $USER@$IP'"
append_line_if_missing "$HOME/.tmux.conf" "set -g mouse on"

mkdir -p "$HOME/worktree_init"
mkdir -p "$HOME/worktrees"

echo "------------------------------------"
echo "Setup Complete!"
echo "Git Name:   $(git config --global user.name)"
echo "SSH Alias:  'connect' -> $USER@$IP"
echo "Init Path:  $HOME/worktree_init"
echo "------------------------------------"
