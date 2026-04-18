# 🔄 Perpetual Dev

An enhanced autonomous coding loop for [OpenClaw](https://github.com/openclaw/openclaw). Based on [Ralph Wiggum](https://ghuntley.com/ralph/), battle-tested through 40+ rounds of real-world development.

**The problem**: Ralph Wiggum is great for a single coding session, but in practice you need it to run overnight, recover from failures, and keep finding new things to improve — without human intervention.

**Perpetual Dev** solves this by adding automatic watchdog recovery, multi-engine support, progress reporting, and self-directed optimization loops.

## How It Works

```
while user hasn't said stop:
    if IMPLEMENTATION_PLAN.md has unchecked tasks:
        loop.sh build N    # Codex or Claude writes code
    else:
        critically review all code
        find new optimization opportunities
        update IMPLEMENTATION_PLAN.md
        continue building
    
    if task times out or fails:
        watchdog auto-recovers within 5 minutes
        resumes from where it left off
```

## What's Different from Ralph Wiggum

| Problem | Ralph Wiggum | Perpetual Dev |
|---------|-------------|---------------|
| Task timeout | Manual restart | Watchdog auto-recovery (5 min) |
| Plan completed | Stops | Auto-reviews code, plans next round |
| Coding engine | Claude Code only | Codex CLI → Claude Code → manual fallback |
| Progress reporting | None | Discord thread with real-time updates |
| Announce failures | Session hangs | State-file based, doesn't depend on announce |
| Discord ID precision | Numbers truncated | `channel:` prefix prevents loss |
| Error spam | Retries flood channel | Failures reported once only |
| Value assessment | None | P0-P3 priority filtering |

## Quick Start

### 1. Install the Skill

```bash
# Copy to your OpenClaw skills directory
cp -r perpetual-dev ~/.openclaw/skills/
# Or symlink
ln -s $(pwd) ~/.openclaw/skills/perpetual-dev
```

### 2. Initialize Your Project

```bash
cd /path/to/your/project

# Copy templates
cp ~/.openclaw/skills/perpetual-dev/templates/PROMPT_build.md .
cp ~/.openclaw/skills/perpetual-dev/templates/PROMPT_plan.md .
cp ~/.openclaw/skills/perpetual-dev/templates/AGENTS_TEMPLATE.md ./AGENTS.md
cp ~/.openclaw/skills/perpetual-dev/templates/IMPLEMENTATION_PLAN_TEMPLATE.md ./IMPLEMENTATION_PLAN.md

# Copy the loop script (choose your engine)
cp ~/.openclaw/skills/perpetual-dev/scripts/loop-codex.sh ./loop.sh
# or
cp ~/.openclaw/skills/perpetual-dev/scripts/loop-claude.sh ./loop.sh
chmod +x loop.sh

# Write your specs
mkdir -p specs
echo "# My Feature Spec" > specs/my-feature.md
```

### 3. Tell OpenClaw

Just say:

> "永动机跑起来" or "start perpetual dev on this project"

OpenClaw will:
1. Detect available coding engines (Codex CLI / Claude Code)
2. Create a Discord thread for progress updates
3. Set up a watchdog cron (every 5 minutes)
4. Spawn the first coding task
5. Keep running until you say stop

### 4. Stop

> "停" or "stop the perpetual dev"

## Coding Engines

Perpetual Dev auto-detects and uses the best available engine:

| Priority | Engine | Command | Cost |
|----------|--------|---------|------|
| 1 | Codex CLI | `codex exec --full-auto` | OpenAI quota |
| 2 | Claude Code | `claude -p --dangerously-skip-permissions` | Anthropic quota |
| 3 | Manual mode | OpenClaw read/write/edit/exec | Model quota |

The orchestration agent (Opus) handles planning and task management. The coding engine handles actual implementation. This separation means most of the token cost goes to the cheaper coding engine.

## Architecture

```
┌─────────────────────────────────────────┐
│           OpenClaw Main Session          │
│         (Opus - orchestration)           │
│                                         │
│  "永动机跑起来"                           │
│       ↓                                 │
│  1. Detect engine                       │
│  2. Create Discord thread               │
│  3. Create watchdog cron                 │
│  4. Spawn coding task                    │
└──────────┬──────────────────────────────┘
           │
    ┌──────▼──────┐     ┌──────────────┐
    │ Coding Task  │     │   Watchdog    │
    │ (Opus+Codex) │     │  (every 5m)  │
    │              │     │              │
    │ loop.sh ─────┤     │ Check alive  │
    │  └─ codex    │     │ If dead →    │
    │     exec     │     │   respawn    │
    │              │     │              │
    └──────┬───────┘     └──────────────┘
           │
    ┌──────▼──────┐
    │    State     │
    │              │
    │ PLAN.md ─────│── Source of truth
    │ git log ─────│── Progress proof  
    │ thread ──────│── Human visibility
    └─────────────┘
```

## State Management

Perpetual Dev never relies on in-memory state or announce callbacks. Everything is persisted:

- **IMPLEMENTATION_PLAN.md** — Task completion status (`[x]` vs `[ ]`)
- **git log** — Proof of work (commits with timestamps)
- **Discord thread** — Human-readable progress trail
- **Watchdog cron** — Heartbeat that ensures continuity

If a task times out, the next spawn reads `IMPLEMENTATION_PLAN.md` and picks up exactly where it left off.

## Value Assessment

Every planning round must answer three questions for each proposed task:

1. **What real problem does this solve?** (Not "code could be better" — "users will hit this bug")
2. **What happens if we don't do it?** (If "nothing" → skip)
3. **How do we verify it worked?** (Must have measurable outcome)

Priority levels:
- **P0**: Will cause production failures (must do)
- **P1**: Users will notice the problem (should do)
- **P2**: Developer experience / code quality (do if time)
- **P3**: Nice to have (do last)

If 3 consecutive rounds find no new tasks, the watchdog auto-pauses and notifies the user.

## Discord Thread Reporting

Progress messages use this format:

```
⏳ Working on: <task description>
✅ Done: <task description> | Changed: <file list>
❌ Failed: <error> (reported once, not repeated)
📊 Round summary: N tasks done, M commits
```

**Important**: Discord thread IDs must use the `channel:` prefix to prevent JavaScript number precision loss:

```
✅ Correct: to = "channel:1494956741056532531"
❌ Wrong:   to = "1494956741056532531"  (will lose precision)
❌ Wrong:   to = 1494956741056532531    (number, not string)
```

## Files

```
perpetual-dev/
├── SKILL.md                              # OpenClaw skill definition
├── README.md                             # This file
├── scripts/
│   ├── loop-codex.sh                     # Loop script for Codex CLI
│   └── loop-claude.sh                    # Loop script for Claude Code
└── templates/
    ├── PROMPT_build.md                   # Build mode prompt
    ├── PROMPT_plan.md                    # Plan mode prompt
    ├── AGENTS_TEMPLATE.md                # Project build commands
    └── IMPLEMENTATION_PLAN_TEMPLATE.md   # Task tracking template
```

## Lessons Learned

These are real problems we hit during 40+ rounds of overnight development:

1. **Announce callbacks are unreliable** — Don't depend on them. Use watchdog + state files.
2. **Discord IDs lose precision in JSON** — Always use `channel:` prefix for thread IDs.
3. **Codex ACP sessions are too short** — Use Codex CLI via loop.sh instead of ACP runtime.
4. **Failure retries cause spam** — Enforce "report failure once" in task instructions.
5. **Gateway restarts orphan sessions** — Watchdog handles this automatically.
6. **"All done" doesn't mean stop** — Auto-review and find new optimization opportunities.
7. **Model selection matters** — Opus for orchestration, Codex for coding. Don't mix them up.

## Credits

- Based on [Ralph Wiggum](https://ghuntley.com/ralph/) by [@GeoffreyHuntley](https://github.com/ghuntley)
- Built for [OpenClaw](https://github.com/openclaw/openclaw)
- Battle-tested on the [Linyn-kf](https://github.com/laolin5564/linyn-kf) project

## License

MIT
