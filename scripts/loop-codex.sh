#!/bin/bash
# Ralph Wiggum Loop — Codex 版本
# Usage: ./loop.sh [plan] [max_iterations]
# Examples:
#   ./loop.sh              # Build mode, unlimited
#   ./loop.sh 20           # Build mode, max 20 iterations
#   ./loop.sh plan         # Plan mode, unlimited
#   ./loop.sh plan 5       # Plan mode, max 5 iterations

# Parse arguments
if [ "$1" = "plan" ]; then
    MODE="plan"
    PROMPT_FILE="PROMPT_plan.md"
    MAX_ITERATIONS=${2:-0}
elif [[ "$1" =~ ^[0-9]+$ ]]; then
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS=$1
else
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS=0
fi

ITERATION=0
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🤖 Ralph Wiggum Loop (Codex 版)"
echo "Mode:   $MODE"
echo "Prompt: $PROMPT_FILE"
echo "Branch: $CURRENT_BRANCH"
[ $MAX_ITERATIONS -gt 0 ] && echo "Max:    $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify prompt file exists
if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: $PROMPT_FILE not found"
    exit 1
fi

# Check for codex CLI
if ! command -v codex &> /dev/null; then
    echo "Error: codex CLI not found"
    echo "Install: npm install -g @openai/codex"
    exit 1
fi

while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo "✅ Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    ITERATION=$((ITERATION + 1))
    echo -e "\n======================== ITERATION $ITERATION ========================\n"

    # Run one iteration with fresh context (Codex CLI)
    cat "$PROMPT_FILE" | codex exec --full-auto

    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        echo "⚠️  codex exited with code $EXIT_CODE"
    fi

    # Push changes if git remote exists
    if git remote get-url origin &>/dev/null; then
        git push origin "$CURRENT_BRANCH" 2>/dev/null || \
            git push -u origin "$CURRENT_BRANCH" 2>/dev/null || \
            echo "⚠️  Push failed (offline or no remote?)"
    fi

    echo "======================== END ITERATION $ITERATION ========================"

    # Check if IMPLEMENTATION_PLAN.md has remaining tasks
    if [ "$MODE" = "plan" ] && [ $ITERATION -ge 1 ]; then
        echo "✅ Plan iteration complete. Review IMPLEMENTATION_PLAN.md then run: ./loop.sh build"
        break
    fi
done
