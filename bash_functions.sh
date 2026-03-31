_ship_usage() {
    echo "Usage: ship [-n name] [-p project-path] [-b base-branch]"
}

_unship_usage() {
    echo "Usage: unship [-n name]"
}

_ship_random_name() {
    LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 4
    echo
}

_ship_require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Error: Required command '$command_name' is not installed."
        return 1
    fi
}

_ship_resolve_repo_root() {
    local project_dir="$1"

    if [ ! -d "$project_dir" ]; then
        echo "Error: Path '$project_dir' not found."
        return 1
    fi

    git -C "$project_dir" rev-parse --show-toplevel 2>/dev/null
}

_ship_init_script_path() {
    local repo_name="$1"

    echo "$HOME/worktree_init/${repo_name}.sh"
}

_ship_branch_name() {
    local name="$1"

    echo "fly/$name"
}

_ship_tmux_startup_command() {
    local init_script="$1"
    local quoted_init_script

    printf -v quoted_init_script '%q' "$init_script"

    cat <<EOF
if [ -f $quoted_init_script ]; then
  echo "Running init script: $init_script"
  bash $quoted_init_script
  init_status=\$?
  if [ \$init_status -ne 0 ]; then
    echo "Init script failed with exit code \$init_status. Codex was not launched."
  else
    codex
  fi
else
  codex
fi
EOF
}

_ship_worktree_path_from_name() {
    local session_name="$1"
    local expected_branch
    local base_dir="$HOME/worktrees"
    local matches=""
    local candidate=""
    local branch_name=""

    expected_branch=$(_ship_branch_name "$session_name")

    if [ ! -d "$base_dir" ]; then
        return 1
    fi

    while IFS= read -r candidate; do
        branch_name=$(git -C "$candidate" rev-parse --abbrev-ref HEAD 2>/dev/null) || continue

        if [ "$branch_name" = "$expected_branch" ]; then
            if [ -n "$matches" ]; then
                echo "Error: Multiple worktrees match branch '$expected_branch'." >&2
                return 2
            fi

            matches="$candidate"
        fi
    done < <(find "$base_dir" -mindepth 2 -maxdepth 2 -type d -name "$session_name" 2>/dev/null)

    if [ -z "$matches" ]; then
        return 1
    fi

    echo "$matches"
}

_ship_repo_root_from_worktree() {
    local worktree_path="$1"
    local common_dir=""

    common_dir=$(git -C "$worktree_path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
    dirname "$common_dir"
}

ship() {
    local OPTIND=1
    local name
    local project_dir="."
    local base_branch="main"
    local repo_root=""
    local repo_name=""
    local worktree_root=""
    local target_dir=""
    local branch_name=""
    local init_script=""
    local startup_command=""

    name=$(_ship_random_name)

    while getopts "n:p:b:" opt; do
        case "$opt" in
            n) name="$OPTARG" ;;
            p) project_dir="$OPTARG" ;;
            b) base_branch="$OPTARG" ;;
            *) _ship_usage; return 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    _ship_require_command git || return 1
    _ship_require_command tmux || return 1
    _ship_require_command codex || return 1

    repo_root=$(_ship_resolve_repo_root "$project_dir") || {
        echo "Error: '$project_dir' is not inside a git repository."
        return 1
    }

    repo_name=$(basename "$repo_root")
    worktree_root="$HOME/worktrees/$repo_name"
    target_dir="$worktree_root/$name"
    branch_name=$(_ship_branch_name "$name")
    init_script=$(_ship_init_script_path "$repo_name")

    mkdir -p "$worktree_root" || {
        echo "Error: Could not create worktree root '$worktree_root'."
        return 1
    }

    if ! git -C "$repo_root" rev-parse --verify "${base_branch}^{commit}" >/dev/null 2>&1; then
        echo "Error: Base branch '$base_branch' does not exist in '$repo_name'."
        return 1
    fi

    if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo "Error: Branch '$branch_name' already exists. Use 'unship -n $name' first."
        return 1
    fi

    if [ -e "$target_dir" ]; then
        echo "Error: Target worktree path '$target_dir' already exists."
        return 1
    fi

    if tmux has-session -t "$name" 2>/dev/null; then
        echo "Error: tmux session '$name' already exists."
        return 1
    fi

    echo "Creating worktree '$name' from '$base_branch'..."
    git -C "$repo_root" worktree add -b "$branch_name" "$target_dir" "$base_branch" || return 1

    tmux new-session -d -s "$name" -c "$target_dir" || {
        echo "Error: Could not create tmux session '$name'."
        return 1
    }

    startup_command=$(_ship_tmux_startup_command "$init_script")
    tmux send-keys -t "$name" "$startup_command" C-m

    if [ -n "$TMUX" ]; then
        tmux switch-client -t "$name"
    else
        tmux attach-session -t "$name"
    fi
}

unship() {
    local OPTIND=1
    local name=""
    local worktree_path=""
    local worktree_status=0
    local repo_root=""
    local branch_name=""
    local should_kill_tmux=0

    while getopts "n:" opt; do
        case "$opt" in
            n) name="$OPTARG" ;;
            *) _unship_usage; return 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    _ship_require_command git || return 1

    if [ -z "$name" ]; then
        _ship_require_command tmux || return 1

        if [ -n "$TMUX" ]; then
            name=$(tmux display-message -p '#S')
        else
            echo "Error: No name provided and not inside a tmux session."
            return 1
        fi
    fi

    echo "Unshipping session '$name'..."

    branch_name=$(_ship_branch_name "$name")
    worktree_path=$(_ship_worktree_path_from_name "$name")
    worktree_status=$?

    if command -v tmux >/dev/null 2>&1; then
        should_kill_tmux=1
    fi

    if [ "$worktree_status" -eq 2 ]; then
        return 1
    fi

    cd "$HOME" || return 1

    if [ "$worktree_status" -eq 0 ] && [ -n "$worktree_path" ]; then
        repo_root=$(_ship_repo_root_from_worktree "$worktree_path") || {
            echo "Warning: Could not resolve parent repo for '$worktree_path'."
            return 1
        }

        git -C "$repo_root" worktree remove --force "$worktree_path" || {
            echo "Warning: Could not remove worktree '$worktree_path'."
            return 1
        }

        git -C "$repo_root" worktree prune >/dev/null 2>&1

        if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch_name"; then
            git -C "$repo_root" branch -D "$branch_name" >/dev/null 2>&1 || {
                echo "Warning: Worktree removed, but branch '$branch_name' could not be deleted."
                return 1
            }
        fi

        echo "Worktree '$name' removed."
    else
        echo "Warning: No worktree found for branch '$branch_name'."
    fi

    if [ "$should_kill_tmux" -eq 1 ]; then
        tmux kill-session -t "$name" 2>/dev/null
    fi
}
