#!/usr/bin/env bash
# Claude Code PostToolUse hook — logs every executed Bash command to a daily
# JSONL file (~/.claude/command-history/YYYY-MM-DD.jsonl) for behavior analysis.
#
# Each line: {"ts", "session", "cwd", "command"}
# Note: commands are captured AFTER the RTK PreToolUse rewrite, i.e. as they
# were actually executed.
#
# This hook must never disturb the session: it always exits 0, even on failure.

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

HISTORY_DIR="${HOME}/.claude/command-history"
mkdir -p "$HISTORY_DIR" || exit 0

echo "$INPUT" | jq -c \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    ts: $ts,
    session: (.session_id // ""),
    cwd: (.cwd // ""),
    command: .tool_input.command
  }' >> "${HISTORY_DIR}/$(date +%F).jsonl" 2>/dev/null

exit 0
