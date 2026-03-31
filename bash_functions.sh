# --- SHIP FUNCTION ---
# Creates a git worktree, sets up a tmux session, and runs init scripts
ship() {
    local OPTIND=1 
    # FIX 1: Use 'head' on urandom instead of 'cat' to prevent hanging
    local NAME=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)
    local PROJECT_DIR="."
    local BASE_BRANCH="main"

    while getopts "n:p:b:" opt; do
      case $opt in
        n) NAME=$OPTARG ;;
        p) PROJECT_DIR=$OPTARG ;;
        b) BASE_BRANCH=$OPTARG ;;
        *) echo "Usage: ship [-n name] [-p project-path] [-b base-branch]"; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    # Save original directory so we can return if it fails
    local START_DIR=$(pwd)
    cd "$PROJECT_DIR" || { echo "Error: Path '$PROJECT_DIR' not found"; return 1; }
    
    local REPO_ROOT=$(pwd)
    local REPO_NAME=$(basename "$REPO_ROOT")
    local WT_ROOT="~/worktrees/$REPO_NAME"
    local TARGET_DIR="$WT_ROOT/$NAME"
    local FULL_BRANCH="fly/$NAME"
    local INIT_SCRIPT="~/worktree_init/${REPO_NAME}.sh"

    mkdir -p "$WT_ROOT"

    echo "Creating worktree: $NAME..."
    # FIX 2: Check if branch exists to avoid git hanging/erroring
    if git rev-parse --verify "$FULL_BRANCH" >/dev/null 2>&1; then
        echo "Error: Branch $FULL_BRANCH already exists. Use 'unship -n $NAME' first."
        cd "$START_DIR"
        return 1
    fi

    git worktree add -b "$FULL_BRANCH" "$TARGET_DIR" "$BASE_BRANCH" || { cd "$START_DIR"; return 1; }

    # Setup Tmux
    tmux new-session -d -s "$NAME"
    tmux send-keys -t "$NAME" "cd '$TARGET_DIR'" C-m

    if [ -f "$REPO_ROOT/$INIT_SCRIPT" ]; then
        tmux send-keys -t "$NAME" "bash '$REPO_ROOT/$INIT_SCRIPT'" C-m
    fi

    tmux send-keys -t "$NAME" "codex" C-m

    if [ -n "$TMUX" ]; then
        tmux switch-client -t "$NAME"
    else
        tmux attach-session -t "$NAME"
    fi
}

# --- UNSHIP FUNCTION ---
# Kills the tmux session and removes the associated git worktree
unship() {
    local OPTIND=1
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
    local WT_PATH=$(git worktree list | grep "\[$NAME\]" | awk '{print $1}')

    # 1. Kill tmux session
    tmux kill-session -t "$NAME" 2>/dev/null

    # 2. Clean up Git Worktree
    if [ -n "$WT_PATH" ]; then
        git worktree remove "$WT_PATH"
        echo "Worktree $NAME removed."
    else
        echo "Warning: No worktree found for branch fly/$NAME"
    fi

    # 3. Go back to root
    cd ~
}