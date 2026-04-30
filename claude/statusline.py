#!/usr/bin/env python3

import json
import sys


def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        print("Claude | Context: Ready")
        return

    model = data.get("model", {}).get("display_name", "Claude")
    ctx = data.get("context_window", {})
    percentage = ctx.get("used_percentage")

    if percentage is not None:
        bar_length = 10
        filled = percentage * bar_length // 100
        bar = "█" * filled + "░" * (bar_length - filled)

        # Absolute token count for early-warning threshold (anticipate auto-compact at 200k)
        current_usage = ctx.get("current_usage") or {}
        absolute_tokens = (
            (current_usage.get("input_tokens") or 0)
            + (current_usage.get("cache_creation_input_tokens") or 0)
            + (current_usage.get("cache_read_input_tokens") or 0)
        )

        # Color logic:
        # - Red: >200k tokens (quality degradation zone, triggers compact) OR >=80% window
        # - Yellow: approaching 200k (~160k) OR >=60% window
        # - Green: safe zone
        if data.get("exceeds_200k_tokens") or percentage >= 80:
            color = "\033[31m"
        elif absolute_tokens >= 160_000 or percentage >= 60:
            color = "\033[33m"
        else:
            color = "\033[32m"

        reset = "\033[0m"
        bold = "\033[1m"

        # Context bar with window size if non-standard
        window_size = ctx.get("context_window_size", 200000)
        window_label = f" ({window_size // 1000}k)" if window_size != 200000 else ""
        context_str = f"Context: {color}{bar} {percentage:3d}%{reset}{window_label}"

        # Warning if exceeding 200k tokens (quality threshold reached)
        if data.get("exceeds_200k_tokens"):
            context_str += f" {bold}{color}!{reset}"

        # Plan usage: rate_limits if on a Claude.ai Pro/Max plan (after first API
        # response), otherwise fall back to client-side cost estimate.
        rate_limits = data.get("rate_limits") or {}
        five_hour = rate_limits.get("five_hour") or {}
        seven_day = rate_limits.get("seven_day") or {}

        if five_hour or seven_day:
            five_pct = int(five_hour.get("used_percentage", 0) or 0)
            seven_pct = int(seven_day.get("used_percentage", 0) or 0)
            worst = max(five_pct, seven_pct)
            if worst >= 80:
                usage_color = "\033[31m"
            elif worst >= 60:
                usage_color = "\033[33m"
            else:
                usage_color = "\033[32m"
            usage_str = f" | Plan: {usage_color}5h {five_pct}% · 7d {seven_pct}%{reset}"
        else:
            cost_usd = (data.get("cost") or {}).get("total_cost_usd") or 0
            usage_str = f" | Cost: ${cost_usd:.2f}"

        # Lines changed
        cost = data.get("cost", {})
        added = cost.get("total_lines_added", 0)
        removed = cost.get("total_lines_removed", 0)
        lines_str = f" | \033[32m+{added}\033[0m \033[31m-{removed}\033[0m" if added or removed else ""

        print(f"{model} | {context_str}{usage_str}{lines_str}")
    else:
        print(f"{model} | Context: Ready")


if __name__ == "__main__":
    main()
