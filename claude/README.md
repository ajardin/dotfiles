# Claude Code configuration

This directory holds the user-global Claude Code configuration, deployed into `~/.claude/` by `make claude`. This
README explains **why** each choice is made, not just what it does.

## `settings.json`

### Runtime

- **`tui: "fullscreen"`** — Claude Code is the primary tool, not a side panel. Fullscreen avoids losing context to
  terminal scroll.
- **`model: "opus[1m]"`** — Opus 5 with the 1M context window, which absorbs large codebases without premature
  compaction. Pinned in `settings.json` so the choice is versioned and portable across machines instead of living in
  per-machine session state.
- **`advisorModel: "fable"`** — the `advisor` tool runs on Fable rather than the session model, so review passes
  come from a second opinion instead of the same model that wrote the code.
- **`effortLevel: "high"`** — reasoning budget per turn. Ran at `xhigh` for a while after the switch back to Opus,
  then dialed back to `high`: the extra budget was not paying for itself on day-to-day work.
- **`alwaysThinkingEnabled: true`** — extended thinking on by default. Prioritizes reasoning quality over latency,
  matching the kind of multi-step engineering work this setup is for.
- **`autoUpdatesChannel: "latest"`** — accept some churn in exchange for new features as soon as they ship.
- **`awaySummaryEnabled: true`** — keeps the built-in `/recap` away-summary on. It's the default, but pinned
  explicitly so the intent is visible and a future Claude Code change can't silently turn it off.
- **`cleanupPeriodDays: 90`** — a quarter of transcript history: long enough to revisit recent work, short enough to
  keep disk usage bounded.

The four keys below are recorded as *what*, not *why* — fill in the rationale when you next touch them.

- **`theme: "dark-ansi"`** — terminal ANSI colours rather than a fixed palette.
- **`autoContinueAtUsageLimit: true`** — an interrupted turn resumes on its own once the usage window resets.
- **`agentPushNotifEnabled: true`** — push notification when a background agent finishes.
- **`skipWorkflowUsageWarning: true`** — suppresses the token-cost warning on the `Workflow` tool.

### Safety

- **`permissions.deny`** — defense-in-depth against accidental reads of `.env`, `.env.*`, `credentials.json`,
  `.pem`, `.key` and `secrets/` in projects, plus home-directory credentials (`~/.ssh`, `~/.aws`, `~/.gnupg`).
  Belt-and-suspenders alongside `.gitignore`: an agent should not be able to ingest these files even if asked.
  The rules bind `Read` only, which is exactly why `global.md` restates the ban for `Grep`, `Bash` and subagents.
- **`permissions.allow`** — short allowlist of read-only commands observed in real transcripts (`docker compose ps`,
  `docker compose config`, a few Datadog/Jira MCP read tools). Reduces prompt fatigue without granting anything that
  mutates state or executes arbitrary code — `docker exec`, `rtk proxy`, `gh api *` and the like stay out on purpose.
  MCP rules are keyed on the *server* name as configured, so a renamed or re-added connector silently stops matching;
  check the entries against `claude mcp list` when prompts reappear for a tool that used to be allowed.
- **`disableBypassPermissionsMode: "disable"`** — bypass mode skips all permission checks. Disabling it ensures
  sensitive operations always prompt, even under time pressure.
- **`skipAutoPermissionPrompt: true`** — the explicit `deny` rules above already gate the dangerous reads; extra
  automatic prompts on top would just be noise. Enabled in tandem with strict denies.

### Output hygiene

- **`attribution: { commit: "", pr: "" }`** — strips "Generated with Claude Code" footers from commits and PRs.
  Authorship belongs to the human, not the tool.
- **`outputStyle: "Concise"`** — answers lead with the result and drop preamble, narration and closing recaps.
  (*What*, not *why* — rationale to fill in.)

## `statusline.py`

Wired through `statusLine` in `settings.json`: `python3 ~/.claude/statusline.py`, `refreshInterval: 60`.

One line, segments separated by `·`: model name, effort level, context-usage bar, plan rate-limit
gauges, current git branch. Missing data drops a segment rather than breaking the line, and any
uncaught failure falls back to printing the model name alone. A status line that throws leaves the
prompt blank, so this one never throws.

The thresholds are the part worth knowing. They apply to the context bar and the rate-limit gauges
alike:

- **Green** below 60%.
- **Yellow** at 60%, early enough to react before context gets pruned.
- **Red** at 80%. Quality degrades and compaction is close. Time to wrap the task up or split the
  conversation.

The context segment takes `used_percentage` from the payload and appends the raw figures
(`total_input_tokens` / `context_window_size`), so it stays correct whatever context window the
model has. Before the first response `used_percentage` is absent, and the segment reads
`Context: Ready`. The percentage is the authoritative half: when the payload omits
`context_window_size`, the used figure is printed alone rather than divided by an assumed window,
which would print a ratio contradicting the bar right beside it.

Two rate-limit gauges follow, `5h` and `7d`, from `rate_limits.five_hour` and
`rate_limits.seven_day`. A Claude.ai Pro/Max session carries them; API-key billing does not, and
the gauges disappear. Each gauge takes its own color and its own `↻` countdown to reset. Past that
reset the payload keeps serving the pre-reset figure until an API response refreshes it, so the
script dims the gauge and flags it `stale` instead of coloring a number it knows is wrong.

The branch comes from reading `.git/HEAD` directly rather than shelling out to `git`. The status
line runs on every refresh, and it has to work from a worktree or submodule, where `.git` is a file
instead of a directory.

## Skills (`skills/`)

Every directory here is symlinked into `~/.claude/skills/`, so a skill is available in every project without being
installed repo by repo. Two kinds live side by side, and the distinction is the whole point:

- **Vendored** — the directories named in the `Makefile`'s `skills_list`, currently six from
  [`mattpocock/skills`](https://github.com/mattpocock/skills). Vendoring rather than installing means the versions in
  use are pinned, reviewable and offline. They are kept **byte-for-byte upstream** so `git diff -- claude/skills`
  after a `make skills-sync` *is* the upstream changelog — the moment one is edited locally, that property is gone
  and every later sync becomes a conflict to hand-resolve. Adapting one means forking it under a new name and
  dropping the original from `skills_list`.
- **Owned** — everything else, `squad-env-branch` today. Written here, maintained here.

`grill-with-docs` and `wait-what` carry `disable-model-invocation: true` upstream: they are `/`-only, deliberately
never auto-triggered.

## Plugins

`enabledPlugins` in `settings.json` selects skills available in every project, so they don't have to be installed
repo by repo.

- **`andrej-karpathy-skills`** — behavioral guardrails (surgical changes, surface assumptions, verifiable success
  criteria). Counterweight against over-engineering.
- **`claude-code-setup`** — recommends hooks / subagents / skills tailored to a given repo. Useful when bootstrapping
  a new project.
- **`claude-md-management`** — audits and improves `CLAUDE.md` files. Keeps project memory from drifting away from
  the code as it evolves.
- **`claude-security`** — multi-agent security scan of a repository. Verified findings come back as patch files to
  apply on demand rather than edits made in place.
- **`code-review`** — PR reviews from the CLI without leaving the editor.
- **`code-simplifier`** — second-pass cleanup after writing code; fights accumulated complexity.
- **`context7`** — fetches up-to-date library docs. Compensates for training-data lag against recent framework
  versions.
- **`frontend-design`** — frontend scaffolding skill with some visual polish, used occasionally.

## RTK (`RTK.md`)

[RTK](https://github.com/rtk-ai/rtk) is a CLI proxy that rewrites verbose commands into token-efficient equivalents
(e.g. `git status` → `rtk git status`). The PreToolUse hook is `rtk hook claude` — a subcommand of the binary, wired
straight into `settings.json`. Nothing repo-side implements it.

Why bother:

- **Cost.** A `git log` or `find` dump can burn thousands of tokens the model doesn't need. RTK trims the noise at
  the source — claimed 60-90% savings on common dev operations.
- **Quality.** Less noise in context = more room for the actual problem, so better reasoning per turn.
- **Transparency.** All rewrite rules live in the Rust binary, so the model doesn't need to know which commands get
  rewritten. `RTK.md` (imported via `@RTK.md` from `global.md`) only documents the meta-commands (`rtk gain`,
  `rtk discover`) the model must call explicitly.

The hook reads `permissions` from `settings.json`: an allowlisted command is rewritten *and* auto-allowed, a denied
one passes through untouched, anything else is rewritten and still prompts. So the allowlist above is what decides
whether RTK saves a prompt as well as tokens.

The cost of using the binary's hook rather than the shell one upstream also ships: no `command -v rtk` guard, so a
machine without rtk gets a failing hook on every `Bash` call instead of a silent no-op. `brew "rtk"` is in the
Brewfile. `rtk init --show`, `rtk hook check '<cmd>'` and `rtk verify` diagnose it.

`RTK.md` is **vendored**, not written here: `rtk init --global` output in slim mode, re-generated by
`make rtk-sync`, same discipline as the skills. Its dangling last line is upstream's, kept verbatim so syncs
stay clean.

## Command history (`hooks/command-history.sh`)

A PostToolUse hook on `Bash` appends every executed command to a daily JSONL file
(`~/.claude/command-history/YYYY-MM-DD.jsonl`) with timestamp, session id and cwd. The goal is studying agent
behavior over time. Commands are captured *after* the RTK rewrite — i.e. as actually executed. The hook always exits
0 so a logging failure can never disturb a session.
