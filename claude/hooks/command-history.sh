#!/usr/bin/env bash
# Claude Code PostToolUse hook — logs every executed Bash command to a daily
# JSONL file (~/.claude/command-history/YYYY-MM-DD.jsonl) for behavior analysis.
#
# Each line: {"ts", "session", "cwd", "command"}
# Note: commands are captured AFTER the RTK PreToolUse rewrite, i.e. as they
# were actually executed.
#
# Old files are pruned on the "cleanupPeriodDays" window from settings.json (see below).
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

# Retention: same window as the transcripts, read from "cleanupPeriodDays" in settings.json so
# there is one number to change rather than two. Falls back to 90 if the key is absent or not a
# plain integer. This hook runs on every Bash call, so the prune is throttled to once a day; the
# stamp is written first, meaning a failed prune waits for tomorrow instead of retrying in a loop.
STAMP="${HISTORY_DIR}/.last-prune"
TODAY=$(date +%F)
if [ "$(cat "$STAMP" 2>/dev/null)" != "$TODAY" ]; then
  echo "$TODAY" > "$STAMP" 2>/dev/null
  DAYS=$(jq -r '.cleanupPeriodDays // 90' "${HOME}/.claude/settings.json" 2>/dev/null)
  case "$DAYS" in '' | *[!0-9]*) DAYS=90 ;; esac
  find "$HISTORY_DIR" -type f -name '*.jsonl' -mtime "+${DAYS}" -delete 2>/dev/null
fi

exit 0
