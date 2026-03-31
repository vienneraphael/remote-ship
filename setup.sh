#!/bin/bash

# Initialize variables
NAME=""
EMAIL=""
IP=""
USER=""

# parse flags
while getopts "n:e:i:u:" opt; do
  case $opt in
    n) NAME=$OPTARG ;;
    e) EMAIL=$OPTARG ;;
    i) IP=$OPTARG ;;
    u) USER=$OPTARG ;;
    *) echo "Usage: $0 -n 'Name' -e 'email' -i 'IP' -u 'user'"; exit 1 ;;
  esac
done

# --- Mandatory Check ---
if [ -z "$NAME" ] || [ -z "$EMAIL" ] || [ -z "$IP" ] || [ -z "$USER" ]; then
    echo "Error: All flags (-n, -e, -i, -u) are mandatory."
    echo "Usage: $0 -n 'Name' -e 'email' -i '192.168.1.1' -u 'pi'"
    exit 1
fi

# Update System
sudo apt-get update && sudo apt-get upgrade -y

# Git Configuration
git config --global user.name "$NAME"
git config --global user.email "$EMAIL"
git config --global push.autoSetupRemote true

# SSH Keygen (Non-interactive)
ssh-keygen -t ed25519 -C "raspberry-pi" -f ~/.ssh/id_ed25519 -N ""

# Install Packages
sudo apt install -y gh npm
curl -LsSf https://astral.sh/uv/install.sh | sh
sudo npm i -g @openai/codex

# --- New Logic ---

# 1. Fetch bash_function.sh and save as .bash_functions
# Replace the URL below with your actual repository raw URL
echo "Fetching bash functions..."
curl -LsSf "https://raw.githubusercontent.com/your-repo/path/bash_function.sh" -o ~/.bash_functions

# 2. Create alias for SSH connection
echo "Creating .bash_aliases..."
echo "alias connect='ssh $USER@$IP'" > ~/.bash_aliases

# 3. Create/Update .bashrc to source these files
echo "Updating .bashrc..."
{
    echo ""
    echo "# Load custom functions and aliases"
    echo "if [ -f ~/.bash_functions ]; then . ~/.bash_functions; fi"
    echo "if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi"
} >> ~/.bashrc

# Source the bashrc for the current session
source ~/.bashrc
mkdir worktree_init
# Feedback
echo "------------------------------------"
echo "Setup Complete!"
echo "Git Name:   $(git config --global user.name)"
echo "SSH Alias:  'connect' -> $USER@$IP"
echo "------------------------------------"

gh auth login
