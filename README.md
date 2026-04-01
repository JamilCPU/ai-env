# AI Environment Launcher

A single-command launcher that opens multiple Windows Terminal tabs, each running a Claude Code session pre-configured for a specific role.

## Roles

| Role | Color | Purpose |
|------|-------|---------|
| Orchestrator | Purple | Plans tasks, coordinates agents, makes architectural decisions |
| Coder | Blue | Implements features using TDD, writes clean tested code |
| Reviewer | Red | Reviews code for quality, security, and correctness |
| DevOps | Green | Manages infrastructure, Docker, deployments, SSH into lab machines |
| Researcher | Amber | Searches for existing solutions, evaluates libraries, writes docs |

Each role starts with a `CLAUDE.md` in its workspace directory that tells Claude its responsibilities, standards, and context.

## Quick Start

### Option 1: Bash (from WSL or Git Bash)

```bash
cd /mnt/f/Dev/ai-env
chmod +x launch.sh
./launch.sh
```

### Option 2: PowerShell (from Windows Terminal)

```powershell
cd F:\Dev\ai-env
.\launch.ps1
```

Both scripts open 5 Windows Terminal tabs, one per role, each in its own workspace with Claude Code running.

## Options

### Bash
```bash
./launch.sh                                        # launch all 5 roles
./launch.sh --roles orchestrator,coder,reviewer    # launch 3 specific roles
./launch.sh --dry-run                              # preview wt commands without launching
./launch.sh --help
```

### PowerShell
```powershell
.\launch.ps1                                               # launch all 5 roles
.\launch.ps1 -Roles orchestrator,coder,reviewer            # launch 3 specific roles
.\launch.ps1 -DryRun                                       # preview wt commands without launching
.\launch.ps1 -Help
```

## How It Works

1. **`roles/<name>/CLAUDE.md`** — defines the role's responsibilities and context
2. **`workspaces/<name>/`** — the working directory for each Claude session (created at launch time)
   - The role's `CLAUDE.md` is copied here on first launch
   - You can edit the workspace copy without affecting the template
3. **`launch.sh` / `launch.ps1`** — sets up workspaces and calls `wt.exe` with one `new-tab` per role

## Customizing Roles

Edit files in `roles/<name>/CLAUDE.md` to change a role's behavior. On next launch, the updated `CLAUDE.md` is copied to new workspaces. Existing workspaces are not overwritten.

To add a new role:

```bash
mkdir -p roles/my-role
cat > roles/my-role/CLAUDE.md <<'EOF'
# My Role
You are a ...
EOF
```

Then launch it:
```bash
./launch.sh --roles my-role
```

## Optional: Docker Compose

If you prefer containerized sessions instead of WSL tabs:

```bash
# Copy and fill in your API key
cp .env.example .env

# Run a single role interactively
docker compose run --rm orchestrator
docker compose run --rm coder

# Or start all in background, then attach
docker compose up -d
docker attach ai-env-orchestrator
```

Each container mounts its workspace volume and the role's `CLAUDE.md`.

## Lab Context

This environment is configured for:

- **PC**: Windows 11 at `192.0.2.99`, WSL + Docker Desktop, projects in `F:/Dev/`
- **Pi1**: `192.0.2.101` — RPi 5, Gitea, OpenClaw, SIGNAL AI News
- **Pi2**: `192.0.2.102` — Raspberry Pi
- **Pi3**: `192.0.2.103` — Raspberry Pi
- SSH to Pis: `wsl ssh user@192.168.1.10X` (SSH key lives in WSL, not Windows)

## Project Structure

```
ai-env/
├── launch.sh              # Main launcher (bash/WSL)
├── launch.ps1             # Main launcher (PowerShell)
├── docker-compose.yml     # Optional containerized sessions
├── .env.example           # Environment variable template
├── .gitignore
├── README.md
├── roles/
│   ├── orchestrator/CLAUDE.md
│   ├── coder/CLAUDE.md
│   ├── reviewer/CLAUDE.md
│   ├── devops/CLAUDE.md
│   └── researcher/CLAUDE.md
└── workspaces/            # Generated at runtime — gitignored
    ├── orchestrator/
    ├── coder/
    ├── reviewer/
    ├── devops/
    └── researcher/
```
