ship() {
    # Default values
    local NAME=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)
    local PROJECT_DIR="."
    local BASE_BRANCH="main"

    local OPTIND
    while getopts "n:p:b:" opt; do
      case $opt in
        n) NAME=$OPTARG ;;
        p) PROJECT_DIR=$OPTARG ;;
        b) BASE_BRANCH=$OPTARG ;;
        *) echo "Usage: ship [-n name] [-p project-path] [-b base-branch]"; return 1 ;;
      esac
    done
    shift $((OPTIND -1))

    # Identify project details while at the original root
    cd "$PROJECT_DIR" || { echo "Project directory not found"; return 1; }
    local REPO_ROOT=$(pwd)
    local REPO_NAME=$(basename "$REPO_ROOT")
    local WT_ROOT="../worktrees/$REPO_NAME"
    local TARGET_DIR="$WT_ROOT/$NAME"
    local FULL_BRANCH="happy/$NAME"
    local INIT_SCRIPT="worktree_init/${REPO_NAME}.sh"

    mkdir -p "$WT_ROOT"

    echo "Creating worktree: $NAME..."
    git worktree add -b "$FULL_BRANCH" "$TARGET_DIR" "$BASE_BRANCH" || return 1

    # Start tmux session detached
    tmux new-session -d -s "$NAME"

    # Send setup commands to the tmux session
    # 1. CD into the new worktree
    # 2. Check and run the init script (using the absolute path from the original root)
    # 3. Run happy codex
    tmux send-keys -t "$NAME" "cd '$TARGET_DIR'" C-m
    
    if [ -f "$REPO_ROOT/$INIT_SCRIPT" ]; then
        echo "Queuing init script in tmux..."
        tmux send-keys -t "$NAME" "bash '$REPO_ROOT/$INIT_SCRIPT'" C-m
    fi

    tmux send-keys -t "$NAME" "codex" C-m

    # Finally, attach to the session
    tmux attach-session -t "$NAME"
}
unship() {
    local NAME=""

    while getopts "n:" opt; do
      case $opt in
        n) NAME=$OPTARG ;;
        *) echo "Usage: unship [-n name]"; return 1 ;;
      esac
    done
    shift $((OPTIND -1))

    # If no name provided via flag, try to get it from the current tmux session
    if [ -z "$NAME" ]; then
        if [ -n "$TMUX" ]; then
            NAME=$(tmux display-message -p '#S')
        else
            echo "Error: No name provided and not inside a tmux session."
            return 1
        fi
    fi

    echo "Unshipping session: $NAME..."

    # Find the worktree path associated with this session's branch
    local WT_PATH=$(git worktree list | grep "\[happy/$NAME\]" | awk '{print $1}')

    # 1. Kill tmux
    tmux kill-session -t "$NAME" 2>/dev/null

    # 2. Clean up Git Worktree
    if [ -n "$WT_PATH" ]; then
        git worktree remove "$WT_PATH"
        echo "Worktree $NAME removed."
    else
        echo "Warning: No worktree found for branch happy/$NAME"
    fi
}
