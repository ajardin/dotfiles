#!/usr/bin/env python3

import json
import os
import sys
from datetime import datetime, timezone

# --- ANSI ---
RED = "\033[31m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"

SEP = f" {DIM}·{RESET} "


def now_epoch():
    return datetime.now(timezone.utc).timestamp()


def fmt_tokens(n):
    n = float(n or 0)
    if n >= 1_000_000:
        v = n / 1_000_000
        return f"{v:.0f}M" if v == int(v) else f"{v:.1f}M"
    if n >= 1000:
        v = n / 1000
        return f"{v:.0f}k" if v >= 10 else f"{v:.1f}k"
    return str(int(n))


def fmt_duration(secs):
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


def color_usage(pct):
    # higher = worse (context, rate limits)
    if pct >= 80:
        return RED
    if pct >= 60:
        return YELLOW
    return GREEN


def bar(pct, length=10):
    pct = max(0, min(100, pct))
    filled = int(round(pct * length / 100))
    return "█" * filled + "░" * (length - filled)


def git_branch(start_dir):
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
    except Exception:
        return None


def gauge(label, window):
    """'5h ▓▓░░░░░░░░ 24% ↻3h25m' from a rate-limit window dict, or None if absent."""
    pct = window.get("used_percentage")
    if pct is None:
        return None
    c = color_usage(pct)
    s = f"{DIM}{label}{RESET} {c}{bar(pct)} {pct:.0f}%{RESET}"
    resets_at = window.get("resets_at")
    if resets_at:
        s += f" {DIM}↻{fmt_duration(resets_at - now_epoch())}{RESET}"
    return s


def hyperlink(url, text):
    """OSC 8 clickable link (BEL-terminated); plain text if no URL."""
    return f"\033]8;;{url}\a{text}\033]8;;\a" if url else text


def review_glyph(state):
    return {
        "approved": f"{GREEN}✓{RESET}",
        "changes_requested": f"{RED}✗{RESET}",
        "pending": f"{YELLOW}●{RESET}",
        "draft": f"{DIM}draft{RESET}",
    }.get(state, "")


def build_line1(data):
    parts = [data.get("model", {}).get("display_name", "Claude")]

    level = (data.get("effort") or {}).get("level")
    if level:
        parts.append(level)

    ctx = data.get("context_window") or {}
    pct = ctx.get("used_percentage")
    if pct is None:
        parts.append("Context: Ready")
    else:
        pct = int(round(pct))
        cu = ctx.get("current_usage") or {}
        used = (
            (cu.get("input_tokens") or 0)
            + (cu.get("cache_creation_input_tokens") or 0)
            + (cu.get("cache_read_input_tokens") or 0)
        )
        total = ctx.get("context_window_size") or 200000
        c = color_usage(pct)
        seg = f"Context: {c}{bar(pct)} {pct:3d}%{RESET}"
        if used:
            seg += f" {DIM}{fmt_tokens(used)}/{fmt_tokens(total)}{RESET}"
        parts.append(seg)

    rl = data.get("rate_limits") or {}
    five = gauge("5h", rl.get("five_hour") or {})
    if five:
        parts.append(five)
    seven = gauge("7d", rl.get("seven_day") or {})
    if seven:
        parts.append(seven)

    branch = git_branch((data.get("workspace") or {}).get("current_dir") or data.get("cwd"))
    if branch:
        parts.append(f"{DIM}⎇{RESET} {branch}")

    return SEP.join(parts)


def build_line2(data):
    """PR status (clickable) + worktree name. '' when neither is present."""
    segs = []

    pr = data.get("pr") or {}
    num = pr.get("number")
    if num is not None:
        seg = hyperlink(pr.get("url"), f"PR #{num}")
        g = review_glyph(pr.get("review_state"))
        if g:
            seg += f" {g}"
        segs.append(seg)

    wt = (data.get("worktree") or {}).get("name") or (data.get("workspace") or {}).get("git_worktree")
    if wt:
        segs.append(f"{DIM}worktree{RESET} {wt}")

    return SEP.join(segs) if segs else ""


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        print("Claude | Context: Ready")
        return

    try:
        print(build_line1(data))
    except Exception:
        print(data.get("model", {}).get("display_name", "Claude"))
        return
    try:
        line2 = build_line2(data)
    except Exception:
        line2 = ""
    if line2:
        print(line2)


if __name__ == "__main__":
    main()
