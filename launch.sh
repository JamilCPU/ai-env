#!/usr/bin/env bash
# =============================================================================
# AI Environment Launcher
# Opens multiple Windows Terminal tabs, each running Claude Code in a role.
# Usage: ./launch.sh [--dry-run] [--roles orchestrator,coder,reviewer,devops,researcher]
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLES_DIR="$SCRIPT_DIR/roles"
WORK_BASE="$SCRIPT_DIR/workspaces"

# Default roles to launch (comma-separated or space-separated)
DEFAULT_ROLES=("orchestrator" "coder" "reviewer" "devops" "researcher")

# Tab color accents (Windows Terminal named colors)
declare -A TAB_COLORS=(
    [orchestrator]="#8B5CF6"   # purple
    [coder]="#3B82F6"          # blue
    [reviewer]="#EF4444"       # red
    [devops]="#10B981"         # green
    [researcher]="#F59E0B"     # amber
)

declare -A TAB_TITLES=(
    [orchestrator]="Orchestrator"
    [coder]="Coder"
    [reviewer]="Reviewer"
    [devops]="DevOps"
    [researcher]="Researcher"
)

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
DRY_RUN=false
SELECTED_ROLES=("${DEFAULT_ROLES[@]}")

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --roles)
            IFS=',' read -ra SELECTED_ROLES <<< "$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--roles role1,role2,...]"
            echo ""
            echo "Available roles: ${DEFAULT_ROLES[*]}"
            echo ""
            echo "Examples:"
            echo "  $0                                          # launch all 5 roles"
            echo "  $0 --roles orchestrator,coder,reviewer      # launch 3 roles"
            echo "  $0 --dry-run                                # preview wt command only"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[ai-env] $*"; }
info() { echo "[ai-env] INFO: $*"; }
warn() { echo "[ai-env] WARN: $*"; }

# Convert WSL path to Windows path (e.g., /mnt/f/Dev → F:\Dev)
wsl_to_win() {
    wslpath -w "$1" 2>/dev/null || echo "$1"
}

# ---------------------------------------------------------------------------
# Validate roles
# ---------------------------------------------------------------------------
validate_roles() {
    for role in "${SELECTED_ROLES[@]}"; do
        if [[ ! -d "$ROLES_DIR/$role" ]]; then
            warn "Role '$role' not found in $ROLES_DIR — skipping"
        fi
    done
}

# ---------------------------------------------------------------------------
# Set up workspaces: create dir + copy CLAUDE.md for each role
# ---------------------------------------------------------------------------
setup_workspaces() {
    log "Setting up workspaces in $WORK_BASE"
    for role in "${SELECTED_ROLES[@]}"; do
        local role_dir="$ROLES_DIR/$role"
        local ws_dir="$WORK_BASE/$role"

        if [[ ! -d "$role_dir" ]]; then
            warn "Skipping unknown role: $role"
            continue
        fi

        mkdir -p "$ws_dir"

        # Copy CLAUDE.md if not already present (don't overwrite user edits)
        if [[ ! -f "$ws_dir/CLAUDE.md" ]]; then
            cp "$role_dir/CLAUDE.md" "$ws_dir/CLAUDE.md"
            info "Created workspace: $ws_dir"
        else
            info "Workspace exists (kept existing CLAUDE.md): $ws_dir"
        fi
    done
}

# ---------------------------------------------------------------------------
# Build the `wt` command string
# Each tab: new-tab --title <title> --tabColor <color> wsl bash -c "cd <workspace> && claude"
# ---------------------------------------------------------------------------
build_wt_command() {
    local wt_args=()
    local first=true

    for role in "${SELECTED_ROLES[@]}"; do
        local role_dir="$ROLES_DIR/$role"
        if [[ ! -d "$role_dir" ]]; then
            continue
        fi

        local ws_dir="$WORK_BASE/$role"
        local title="${TAB_TITLES[$role]:-$role}"
        local color="${TAB_COLORS[$role]:-#FFFFFF}"

        # WSL path for the workspace (wt launches from Windows, so use wsl -e bash)
        # We pass the workspace path as a WSL path inside bash -c
        local wsl_ws
        wsl_ws=$(wslpath -u "$(wsl_to_win "$ws_dir")" 2>/dev/null || echo "$ws_dir")

        local tab_cmd
        tab_cmd="wsl bash -c \"cd '$wsl_ws' && exec claude\""

        if [[ "$first" == "true" ]]; then
            # First tab uses "new-tab" (wt opens with its own first tab, so we replace it)
            wt_args+=("new-tab" "--title" "$title" "--tabColor" "$color" "wsl" "bash" "-c" "cd '$wsl_ws' && exec claude")
            first=false
        else
            wt_args+=(";")
            wt_args+=("new-tab" "--title" "$title" "--tabColor" "$color" "wsl" "bash" "-c" "cd '$wsl_ws' && exec claude")
        fi
    done

    # Join into a single string for display/exec
    printf '%q ' "wt.exe" "${wt_args[@]}"
}

# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------
launch() {
    local first=true
    local wt_cmd="wt.exe"

    for role in "${SELECTED_ROLES[@]}"; do
        local role_dir="$ROLES_DIR/$role"
        if [[ ! -d "$role_dir" ]]; then
            continue
        fi

        local ws_dir="$WORK_BASE/$role"
        local title="${TAB_TITLES[$role]:-$role}"
        local color="${TAB_COLORS[$role]:-#FFFFFF}"
        local wsl_ws="$ws_dir"

        if [[ "$first" == "true" ]]; then
            wt_cmd+=" new-tab --title \"$title\" --tabColor \"$color\" wsl bash -c \"cd '$wsl_ws' && exec claude\""
            first=false
        else
            wt_cmd+=" \; new-tab --title \"$title\" --tabColor \"$color\" wsl bash -c \"cd '$wsl_ws' && exec claude\""
        fi
    done

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN — would execute:"
        echo ""
        echo "  $wt_cmd"
        echo ""
        log "Workspaces:"
        for role in "${SELECTED_ROLES[@]}"; do
            [[ -d "$ROLES_DIR/$role" ]] && echo "  $role → $WORK_BASE/$role"
        done
        return 0
    fi

    log "Launching ${#SELECTED_ROLES[@]} Claude sessions..."
    log "Workspaces: $WORK_BASE"
    echo ""

    # Execute the wt command
    eval "$wt_cmd"

    echo ""
    log "Done. Windows Terminal tabs launched:"
    for role in "${SELECTED_ROLES[@]}"; do
        [[ -d "$ROLES_DIR/$role" ]] && echo "  - ${TAB_TITLES[$role]:-$role} (${TAB_COLORS[$role]:-default})"
    done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    log "AI Environment Launcher"
    log "Roles: ${SELECTED_ROLES[*]}"
    echo ""

    validate_roles
    setup_workspaces
    launch
}

main
