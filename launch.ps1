# =============================================================================
# AI Environment Launcher (PowerShell)
# Opens multiple Windows Terminal tabs, each running Claude Code in a role.
# Usage: .\launch.ps1 [-DryRun] [-Roles orchestrator,coder,reviewer,devops,researcher]
# =============================================================================

param(
    [switch]$DryRun,
    [string]$Roles = "orchestrator,coder,reviewer,devops,researcher",
    [switch]$Help
)

if ($Help) {
    Write-Host "Usage: .\launch.ps1 [-DryRun] [-Roles role1,role2,...] [-Help]"
    Write-Host ""
    Write-Host "Available roles: orchestrator, coder, reviewer, devops, researcher"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\launch.ps1                                          # launch all 5 roles"
    Write-Host "  .\launch.ps1 -Roles orchestrator,coder,reviewer       # launch 3 roles"
    Write-Host "  .\launch.ps1 -DryRun                                  # preview wt command only"
    exit 0
}

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
$ScriptDir = $PSScriptRoot
$RolesDir  = Join-Path $ScriptDir "roles"
$WorkBase  = Join-Path $ScriptDir "workspaces"

$TabColors = @{
    orchestrator = "#8B5CF6"
    coder        = "#3B82F6"
    reviewer     = "#EF4444"
    devops       = "#10B981"
    researcher   = "#F59E0B"
}

$TabTitles = @{
    orchestrator = "Orchestrator"
    coder        = "Coder"
    reviewer     = "Reviewer"
    devops       = "DevOps"
    researcher   = "Researcher"
}

# ---------------------------------------------------------------------------
# Parse roles
# ---------------------------------------------------------------------------
$SelectedRoles = $Roles -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Log  { param($msg) Write-Host "[ai-env] $msg" -ForegroundColor Cyan }
function Info { param($msg) Write-Host "[ai-env] INFO: $msg" -ForegroundColor Green }
function Warn { param($msg) Write-Host "[ai-env] WARN: $msg" -ForegroundColor Yellow }

# Convert a Windows path to a WSL-compatible path (e.g. F:\Dev -> /mnt/f/Dev)
function ConvertTo-WslPath {
    param([string]$WinPath)
    # Drive letter e.g. F:\Dev\ai-env -> /mnt/f/Dev/ai-env
    $result = wsl wslpath -u ($WinPath -replace '\\', '/')
    return $result.Trim()
}

# ---------------------------------------------------------------------------
# Set up workspaces
# ---------------------------------------------------------------------------
function Setup-Workspaces {
    Log "Setting up workspaces in $WorkBase"

    foreach ($role in $SelectedRoles) {
        $roleDir = Join-Path $RolesDir $role
        $wsDir   = Join-Path $WorkBase $role

        if (-not (Test-Path $roleDir)) {
            Warn "Role '$role' not found in $RolesDir - skipping"
            continue
        }

        if (-not (Test-Path $wsDir)) {
            New-Item -ItemType Directory -Path $wsDir -Force | Out-Null
        }

        $claudeMdSrc  = Join-Path $roleDir "CLAUDE.md"
        $claudeMdDest = Join-Path $wsDir   "CLAUDE.md"

        if (-not (Test-Path $claudeMdDest)) {
            Copy-Item $claudeMdSrc $claudeMdDest
            Info "Created workspace: $wsDir"
        } else {
            Info "Workspace exists (kept existing CLAUDE.md): $wsDir"
        }
    }
}

# ---------------------------------------------------------------------------
# Build and launch wt command
# ---------------------------------------------------------------------------
function Launch-Terminals {
    $validRoles = $SelectedRoles | Where-Object { Test-Path (Join-Path $RolesDir $_) }

    if ($validRoles.Count -eq 0) {
        Write-Host "[ai-env] ERROR: No valid roles found." -ForegroundColor Red
        exit 1
    }

    # Build the wt argument list.
    # Each tab: new-tab --title TITLE --tabColor COLOR wsl bash -c "cd PATH && exec claude"
    # Tabs are separated by a lone semicolon element in the array.

    $wtArgs = [System.Collections.Generic.List[string]]::new()
    $first  = $true

    foreach ($role in $validRoles) {
        $wsDir = Join-Path $WorkBase $role
        $title = if ($TabTitles[$role]) { $TabTitles[$role] } else { $role }
        $color = if ($TabColors[$role]) { $TabColors[$role] } else { "#FFFFFF" }

        # Convert workspace path to WSL path for the bash -c argument
        $wslPath = ConvertTo-WslPath $wsDir

        if (-not $first) {
            $wtArgs.Add(";")
        }

        $wtArgs.Add("new-tab")
        $wtArgs.Add("--title")
        $wtArgs.Add($title)
        $wtArgs.Add("--tabColor")
        $wtArgs.Add($color)
        $wtArgs.Add("wsl")
        $wtArgs.Add("bash")
        $wtArgs.Add("-c")
        $wtArgs.Add("cd '$wslPath' && exec claude")

        $first = $false
    }

    if ($DryRun) {
        Log "DRY RUN - wt.exe command that would be executed:"
        Write-Host ""
        Write-Host ("  wt.exe " + ($wtArgs -join " ")) -ForegroundColor DarkGray
        Write-Host ""
        Log "Workspaces:"
        foreach ($role in $validRoles) {
            $wsDir = Join-Path $WorkBase $role
            Write-Host "  $role -> $wsDir" -ForegroundColor DarkGray
        }
        return
    }

    Log "Launching $($validRoles.Count) Claude sessions in Windows Terminal..."

    & wt.exe @wtArgs

    Write-Host ""
    Log "Done. Tabs launched:"
    foreach ($role in $validRoles) {
        $title = if ($TabTitles[$role]) { $TabTitles[$role] } else { $role }
        $color = if ($TabColors[$role]) { $TabColors[$role] } else { "default" }
        Write-Host "  - $title ($color)" -ForegroundColor Green
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Log "AI Environment Launcher"
Log "Roles: $($SelectedRoles -join ', ')"
Write-Host ""

Setup-Workspaces
Launch-Terminals
