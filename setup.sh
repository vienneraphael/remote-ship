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

DOCKER_PACKAGES_TO_REMOVE=(
    docker.io
    docker-compose
    docker-compose-v2
    docker-doc
    podman-docker
    containerd
    runc
)

DOCKER_PACKAGES_TO_INSTALL=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)

echo "Configuring Docker apt repository..."
INSTALLED_DOCKER_PACKAGES=()
for package in "${DOCKER_PACKAGES_TO_REMOVE[@]}"; do
    if dpkg -s "$package" >/dev/null 2>&1; then
        INSTALLED_DOCKER_PACKAGES+=("$package")
    fi
done

if [ "${#INSTALLED_DOCKER_PACKAGES[@]}" -gt 0 ]; then
    sudo apt-get remove -y "${INSTALLED_DOCKER_PACKAGES[@]}"
fi

retry "$RETRY_ATTEMPTS" sudo apt-get update || {
    echo "Error: Failed to update apt package lists before Docker setup after $RETRY_ATTEMPTS attempts."
    exit 1
}

retry "$RETRY_ATTEMPTS" sudo apt-get install -y ca-certificates curl || {
    echo "Error: Failed to install Docker apt prerequisites after $RETRY_ATTEMPTS attempts."
    exit 1
}

sudo install -m 0755 -d /etc/apt/keyrings
retry "$RETRY_ATTEMPTS" sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc || {
    echo "Error: Failed to download Docker GPG key after $RETRY_ATTEMPTS attempts."
    exit 1
}
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

retry "$RETRY_ATTEMPTS" sudo apt-get update || {
    echo "Error: Failed to refresh apt package lists for Docker after $RETRY_ATTEMPTS attempts."
    exit 1
}

git config --global user.name "$NAME"
git config --global user.email "$EMAIL"
git config --global push.autoSetupRemote true

ssh-keygen -t ed25519 -C "raspberry-pi" -f "$HOME/.ssh/id_ed25519" -N ""

retry "$RETRY_ATTEMPTS" sudo apt-get install -y \
    bubblewrap \
    gh \
    npm \
    tmux \
    "${DOCKER_PACKAGES_TO_INSTALL[@]}" || {
    echo "Error: Failed to install apt packages after $RETRY_ATTEMPTS attempts."
    exit 1
}

<<<<<<< Updated upstream
retry "$RETRY_ATTEMPTS" sudo apt install -y just || {
    echo "Error: Failed to install just after $RETRY_ATTEMPTS attempts."
=======
retry "$RETRY_ATTEMPTS" sudo apt install -y ripgrep || {
    echo "Error: Failed to install ripgrep after $RETRY_ATTEMPTS attempts."
>>>>>>> Stashed changes
    exit 1
}

retry "$RETRY_ATTEMPTS" sudo systemctl start docker || {
    echo "Error: Failed to start Docker after $RETRY_ATTEMPTS attempts."
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
