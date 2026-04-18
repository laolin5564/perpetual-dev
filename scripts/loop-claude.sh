#!/bin/bash
# Perpetual Dev Loop — Claude Code 版本
# Usage: ./loop.sh [plan] [max_iterations]

# 中转站配置（按需修改）
# export ANTHROPIC_BASE_URL="https://your-relay.com"
# export ANTHROPIC_API_KEY="sk-xxx"

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
echo "🤖 Perpetual Dev Loop (Claude Code)"
echo "Mode:   $MODE"
echo "Prompt: $PROMPT_FILE"
echo "Branch: $CURRENT_BRANCH"
[ $MAX_ITERATIONS -gt 0 ] && echo "Max:    $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: $PROMPT_FILE not found"
    exit 1
fi

if ! command -v claude &> /dev/null; then
    echo "Error: claude CLI not found"
    exit 1
fi

while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo "✅ Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    ITERATION=$((ITERATION + 1))
    echo -e "\n======================== ITERATION $ITERATION ========================\n"

    cat "$PROMPT_FILE" | claude -p --dangerously-skip-permissions

    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        echo "⚠️  claude exited with code $EXIT_CODE"
    fi

    if git remote get-url origin &>/dev/null; then
        git push origin "$CURRENT_BRANCH" 2>/dev/null || echo "⚠️  Push failed"
    fi

    echo "======================== END ITERATION $ITERATION ========================"

    if [ "$MODE" = "plan" ] && [ $ITERATION -ge 1 ]; then
        echo "✅ Plan iteration complete."
        break
    fi
done
