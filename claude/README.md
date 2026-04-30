# Claude Code configuration

This directory holds the user-global Claude Code configuration, deployed into `~/.claude/` by `make claude`. This
README explains **why** each choice is made, not just what it does.

## `settings.json`

### Runtime

- **`tui: "fullscreen"`** — Claude Code is the primary tool, not a side panel. Fullscreen avoids losing context to
  terminal scroll.
- **`model: "opus[1m]"`** — Opus is the most capable model available; the 1M context window absorbs large codebases
  without premature compaction.
- **`effortLevel: "xhigh"`** — prioritizes reasoning quality over latency. Matches the kind of multi-step engineering
  work this setup is for.
- **`autoUpdatesChannel: "latest"`** — accept some churn in exchange for new features as soon as they ship.
- **`awaySummaryEnabled: true`** — keeps the built-in `/recap` away-summary on. It's the default, but pinned
  explicitly so the intent is visible and a future Claude Code change can't silently turn it off.
- **`cleanupPeriodDays: 90`** — a quarter of transcript history: long enough to revisit recent work, short enough to
  keep disk usage bounded.

### Safety

- **`permissions.deny`** — defense-in-depth against accidental reads of `.env`, `.pem`, `.key`, `secrets/`.
  Belt-and-suspenders alongside `.gitignore`: an agent should not be able to ingest these files even if asked.
- **`disableBypassPermissionsMode: "disable"`** — bypass mode skips all permission checks. Disabling it ensures
  sensitive operations always prompt, even under time pressure.
- **`skipAutoPermissionPrompt: true`** — the explicit `deny` rules above already gate the dangerous reads; extra
  automatic prompts on top would just be noise. Enabled in tandem with strict denies.

### Output hygiene

- **`attribution: { commit: "", pr: "" }`** — strips "Generated with Claude Code" footers from commits and PRs.
  Authorship belongs to the human, not the tool.

## `statusline.py`

Shows the model name, a 10-cell context-usage bar, and lines added/removed. The point is the thresholds:

- **Green** below 60% / 160k tokens — safe zone.
- **Yellow** at 60% or 160k tokens — early warning that auto-compact is approaching.
- **Red** above 80% or once `exceeds_200k_tokens` flips — quality degrades and Claude Code is about to compact. Time
  to wrap the task up or split the conversation.

The 160k yellow threshold is deliberately below the 200k compaction trigger so there is room to react before context
gets pruned.

A second segment shows **plan usage**: on a Claude.ai Pro/Max session the JSON exposes `rate_limits.five_hour` and
`rate_limits.seven_day`, so the line shows `Plan: 5h X% · 7d Y%` colored by the worst of the two (same green/yellow/
red thresholds as the context bar). When `rate_limits` is absent (API-key billing, or pre-first-response on Max), it
falls back to `Cost: $X.XX` from `cost.total_cost_usd`. The doc is explicit that this cost is a *client-side
estimate* and may differ from actual billing — meaningful as a sanity check on API key, purely informational on Max.
The single script handles both laptops without branching on hostname.

## Plugins

`enabledPlugins` in `settings.json` selects skills available in every project, so they don't have to be installed
repo by repo.

- **`andrej-karpathy-skills`** — behavioral guardrails (surgical changes, surface assumptions, verifiable success
  criteria). Counterweight against over-engineering.
- **`claude-code-setup`** — recommends hooks / subagents / skills tailored to a given repo. Useful when bootstrapping
  a new project.
- **`claude-md-management`** — audits and improves `CLAUDE.md` files. Keeps project memory from drifting away from
  the code as it evolves.
- **`code-review`** — PR reviews from the CLI without leaving the editor.
- **`code-simplifier`** — second-pass cleanup after writing code; fights accumulated complexity.
- **`context7`** — fetches up-to-date library docs. Compensates for training-data lag against recent framework
  versions.
- **`frontend-design`** — frontend scaffolding skill with some visual polish, used occasionally.
- **`slack`** — send Slack messages from Claude Code (status updates, PR links).
- **`warp`** — native integration with the Warp terminal.

## RTK (`RTK.md`, `hooks/rtk-rewrite.sh`)

[RTK](https://github.com/rtk-ai/rtk) is a CLI proxy that rewrites verbose commands into token-efficient equivalents
(e.g. `git status` → `rtk git status`). The PreToolUse hook `claude/hooks/rtk-rewrite.sh` intercepts every `Bash`
call and delegates to `rtk rewrite` for the decision (substitute, pass through, deny, or prompt).

Why bother:

- **Cost.** A `git log` or `find` dump can burn thousands of tokens the model doesn't need. RTK trims the noise at
  the source — claimed 60-90% savings on common dev operations.
- **Quality.** Less noise in context = more room for the actual problem, so better reasoning per turn.
- **Transparency.** The hook is deliberately minimal: all rewrite rules live in the Rust binary, so the model
  doesn't need to know which commands get rewritten. `RTK.md` (imported via `@RTK.md` from `global.md`) only
  documents the meta-commands (`rtk gain`, `rtk discover`) the model must call explicitly.

The exit-code contract (`0` allow, `1` passthrough, `2` deny, `3` ask) is the integration boundary; everything else
lives inside `rtk` itself, which keeps repo-side logic out of this dotfiles tree.
