#!/usr/bin/env python3
"""Claude Code status line.

Reads the status-line JSON payload from stdin and prints one line:
model, effort level, context usage, rate-limit gauges, git branch.
Any failure degrades to a minimal fallback — the status line must never crash.
"""

from __future__ import annotations

import json
import os
import sys
import time

# --- ANSI ---
RED = "\033[31m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RESET = "\033[0m"
DIM = "\033[2m"

SEP = f" {DIM}·{RESET} "

BAR_LENGTH = 10
# Usage thresholds, in percent, so they hold whatever the context window. Shared by the
# context bar and the rate-limit gauges: for both, a higher percentage is worse.
WARN_PCT = 60
DANGER_PCT = 80


def fmt_tokens(n: float | None) -> str:
    n = float(n or 0)
    if n >= 1_000_000:
        v = n / 1_000_000
        return f"{v:.0f}M" if v == int(v) else f"{v:.1f}M"
    if n >= 1000:
        v = n / 1000
        return f"{v:.0f}k" if v >= 10 else f"{v:.1f}k"
    return str(int(n))


def fmt_duration(secs: float) -> str:
    secs = int(secs)
    if secs <= 0:
        return "now"
    d, rem = divmod(secs, 86400)
    h, rem = divmod(rem, 3600)
    m, _ = divmod(rem, 60)
    if d > 0:
        return f"{d}d{h}h"
    if h > 0:
        return f"{h}h{m}m"
    return f"{m}m"


def usage_color(pct: float) -> str:
    # higher = worse (context, rate limits)
    if pct >= DANGER_PCT:
        return RED
    if pct >= WARN_PCT:
        return YELLOW
    return GREEN


def bar(pct: float, length: int = BAR_LENGTH) -> str:
    pct = max(0, min(100, pct))
    filled = int(round(pct * length / 100))
    return "█" * filled + "░" * (length - filled)


def git_branch(start_dir: str | None) -> str | None:
    """Current branch by reading .git/HEAD directly (no subprocess). None if not a repo."""
    try:
        if not start_dir:
            return None
        d = os.path.abspath(os.path.expanduser(start_dir))
        git_path = None
        while True:
            cand = os.path.join(d, ".git")
            if os.path.exists(cand):
                git_path = cand
                break
            parent = os.path.dirname(d)
            if parent == d:
                return None
            d = parent
        if os.path.isfile(git_path):
            # worktree / submodule: ".git" is a file "gitdir: <path>"
            with open(git_path) as f:
                content = f.read().strip()
            if not content.startswith("gitdir:"):
                return None
            gitdir = content[len("gitdir:"):].strip()
            if not os.path.isabs(gitdir):
                gitdir = os.path.normpath(os.path.join(os.path.dirname(git_path), gitdir))
        else:
            gitdir = git_path
        with open(os.path.join(gitdir, "HEAD")) as f:
            ref = f.read().strip()
        if ref.startswith("ref:"):
            return ref.split("/", 2)[-1]  # refs/heads/feat/x -> feat/x
        return ref[:7] if ref else None   # detached HEAD -> short sha
    except (OSError, UnicodeDecodeError):
        return None


def gauge(label: str, window: dict) -> str | None:
    """'5h ▓▓░░░░░░░░ 24% ↻3h25m' from a rate-limit window dict, or None if absent."""
    pct = window.get("used_percentage")
    if pct is None:
        return None
    resets_at = window.get("resets_at")
    remaining = resets_at - time.time() if resets_at else None
    # Past its reset the window has restarted, but the payload keeps serving the
    # pre-reset figure until an API response refreshes it — flag it rather than
    # colour a number we know is wrong.
    stale = remaining is not None and remaining <= 0
    c = DIM if stale else usage_color(pct)
    s = f"{DIM}{label}{RESET} {c}{bar(pct)} {pct:.0f}%{RESET}"
    if stale:
        return f"{s} {DIM}stale{RESET}"
    if remaining is not None:
        s += f" {DIM}↻{fmt_duration(remaining)}{RESET}"
    return s


def model_name(data: dict) -> str:
    """Model label, resilient to a null 'model' or 'display_name' — also the crash fallback."""
    return (data.get("model") or {}).get("display_name") or "Claude"


def effort_segment(data: dict) -> str | None:
    return (data.get("effort") or {}).get("level") or None


def context_segment(data: dict) -> str | None:
    ctx = data.get("context_window") or {}
    pct = ctx.get("used_percentage")
    if pct is None:
        return "Context: Ready"
    pct = int(round(pct))
    # total_input_tokens is the payload's own sum of input + cache creation + cache read.
    used = ctx.get("total_input_tokens") or 0
    total = ctx.get("context_window_size") or 0
    c = usage_color(pct)
    seg = f"Context: {c}{bar(pct)} {pct:d}%{RESET}"
    if used:
        # No assumed window: a guessed total would contradict the percentage beside it.
        raw = f"{fmt_tokens(used)}/{fmt_tokens(total)}" if total else fmt_tokens(used)
        seg += f" {DIM}{raw}{RESET}"
    return seg


def rate_limit_segments(data: dict) -> list[str]:
    rl = data.get("rate_limits") or {}
    return [g for label, key in (("5h", "five_hour"), ("7d", "seven_day"))
            if (g := gauge(label, rl.get(key) or {}))]


def branch_segment(data: dict) -> str | None:
    branch = git_branch((data.get("workspace") or {}).get("current_dir") or data.get("cwd"))
    return f"{DIM}⎇{RESET} {branch}" if branch else None


def build_status(data: dict) -> str:
    parts = [model_name(data)]

    # Guarded one by one: a malformed field costs its own segment, never the whole line.
    # Without this, something like a non-numeric "resets_at" would drop the context bar and
    # the branch too, leaving the model name alone.
    for segment in (effort_segment, context_segment, rate_limit_segments, branch_segment):
        try:
            value = segment(data)
        except Exception:
            continue
        if isinstance(value, list):
            parts.extend(value)
        elif value:
            parts.append(value)

    return SEP.join(parts)


def main() -> None:
    # Broad excepts are deliberate: a status line must always print something.
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}
    if not isinstance(data, dict):
        data = {}
    try:
        print(build_status(data))
    except Exception:
        # model_name only touches dicts, so this cannot raise in turn.
        print(model_name(data))


if __name__ == "__main__":
    main()
