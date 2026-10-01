# Claude Code configuration

This directory holds the user-global Claude Code configuration, which `make claude` deploys into `~/.claude/`. This
README explains why each choice was made, not only what it does.

## `settings.json`

### Runtime

- **`tui: "fullscreen"`.** Claude Code is the primary tool, not a side panel. In fullscreen, terminal scrolling does not
  push context out of view.
- **`model: "opus[1m]"`.** Opus 5 with the 1M context window, which holds large codebases without early compaction. The
  setting lives in `settings.json`, so the choice is versioned and the same on every machine instead of living in
  per-machine session state.
- **`advisorModel: "fable"`.** The `advisor` tool runs on Fable instead of the session model, so reviews come from a
  second model, not the one that wrote the code.
- **`modelSettings`.** Sets the reasoning budget per model: `effortLevel: "high"` for `claude-opus-5-5` and
  `effortLevel: "medium"` for `claude-fable-5-1`. The single `effortLevel` it replaced ran at `xhigh` for a while after
  the switch back to Opus, then went back to `high`, because the extra budget did not pay off on day-to-day work. The
  reason for `medium` on Fable is not recorded yet; add it the next time you change this key.
- **`alwaysThinkingEnabled: true`.** Extended thinking is on by default. This favors reasoning quality over latency,
  which suits the multi-step engineering work this setup is for.
- **`autoUpdatesChannel: "latest"`.** The setup accepts some churn in exchange for new features as soon as they ship.
- **`awaySummaryEnabled: true`.** Keeps the built-in `/recap` away summary on. This is the default, but the key is set
  explicitly so the intent is visible and a future Claude Code change cannot turn it off without notice.
- **`cleanupPeriodDays: 90`.** A quarter of transcript history. That is long enough to revisit recent work and short
  enough to keep disk usage bounded.

The four keys below record what they do, not why. Add the rationale the next time you change one.

- **`theme: "dark-ansi"`.** Uses the terminal's ANSI colours instead of a fixed palette.
- **`autoContinueAtUsageLimit: true`.** An interrupted turn resumes on its own once the usage window resets.
- **`agentPushNotifEnabled: true`.** Sends a push notification when a background agent finishes.
- **`skipWorkflowUsageWarning: true`.** Hides the token-cost warning on the `Workflow` tool.

### Safety

- **`permissions.deny`.** Blocks accidental reads of `.env`, `.env.*`, `credentials.json`, `.pem`, `.key` and `secrets/`
  in projects, plus home-directory credentials (`~/.ssh`, `~/.aws`, `~/.gnupg`). It adds a second layer to `.gitignore`,
  so an agent cannot read these files even if asked. The rules bind `Read` only, which is why `global.md` restates the
  ban for `Grep`, `Bash` and subagents.
- **`permissions.allow`.** A short allowlist of read-only commands seen in real transcripts (`docker compose ps`,
  `docker compose config`, a few Datadog and Jira MCP read tools). It cuts down on prompts without allowing anything
  that changes state or runs arbitrary code, so `docker exec`, `rtk proxy`, `gh api *` and similar commands stay out on
  purpose. MCP rules match the server name as configured, so a renamed or re-added connector stops matching without
  warning. When prompts come back for a tool that used to be allowed, check the entries against `claude mcp list`.
- **`disableBypassPermissionsMode: "disable"`.** Bypass mode skips all permission checks. Disabling it means sensitive
  operations always prompt, even under time pressure.
- **`skipAutoPermissionPrompt: true`.** The explicit `deny` rules above already block the dangerous reads, so extra
  automatic prompts would only add noise. It is set together with the strict denies.

### Output hygiene

- **`attribution: { commit: "", pr: "" }`.** Removes the "Generated with Claude Code" footers from commits and PRs. The
  human is the author, not the tool.

## `global.md`

`make claude` symlinks it to `~/.claude/CLAUDE.md`, because Claude Code requires that filename in `~/.claude/`. The repo
source is named `global.md` so it is never confused with this repo's own `CLAUDE.md`. It imports `@RTK.md`, then holds
the rules that apply to every project on every machine.

`Language` makes Claude reply in English whatever language the prompt is in. It explicitly excludes content written for
others, since a PR description or a review comment follows its own audience.

`Database access` and `Credential files` are the two standing bans. They name `Grep`, `Bash` and subagents too, because
the `permissions.deny` rules above only bind `Read`.

The four rules in between came from the May to September 2026 usage reports across both machines, where *wrong approach*
was the top friction category on each side. The incidents behind them are all on record:

- **`Evidence before claims`.** The recurring failure is stating a conclusion from partial evidence. Claude flagged a
  Ghostty config as "never loaded" and had to retract the finding. It proposed a config line that was already the tool's
  default. It declared a skill not installed because a session listing did not show it, while the skill was on disk.
  Splitting output into proven findings and a `Hypotheses` heading turns those two-round exchanges into one.
- **`Scope`.** It covers two failures that look opposite but come from the same missing instruction. Claude delivered
  work nobody asked for (a severity chart, extra tests, two different error shapes for one auth guard), and declined
  requested work on invented scope grounds. The rule states both directions, so neither needs asking again.
- **`Handoffs`.** A data-import session stalled on "awaiting your validation", and decoding that phrase took a whole
  clarification exchange. A numbered list of decisions is actionable; that phrase is not.
- **`Third-party facts`.** Claude built a Spotify for Artists pitch on invented styles, cultures and moods, and the user
  discarded every one once real screenshots arrived. `context7` covers library docs, not product UIs, so this rule
  covers that gap. It is written against any external service's vocabulary, not that one incident's field names, so it
  applies to an unfamiliar API or CLI too.

## `statusline.py`

`statusLine` in `settings.json` runs it as `python3 ~/.claude/statusline.py` with `refreshInterval: 60`.

It prints one line of segments separated by `·`: model name, effort level, context-usage bar, plan rate-limit gauges and
current git branch. Missing data drops a segment instead of breaking the line, and any uncaught failure falls back to
printing the model name alone. A status line that throws leaves the prompt blank, so this one never throws.

The script guards against malformed data separately from missing data, and builds each segment inside its own `try`.
Before that, one bad field broke the whole line. A `resets_at` that arrived as an ISO-8601 string instead of an epoch
raised an error inside the gauge, and the outer fallback then printed the model name alone. That dropped the context bar
and the branch, although both could still be computed. Now only the faulty segment disappears.

The thresholds apply to the context bar and the rate-limit gauges alike:

- **Green** below 60%.
- **Yellow** at 60%, early enough to react before context gets pruned.
- **Red** at 80%. Quality degrades and compaction is close, so it is time to finish the task or split the conversation.

The context segment takes `used_percentage` from the payload and appends the raw figures (`total_input_tokens` /
`context_window_size`), so it stays correct for any context window size. Before the first response, `used_percentage` is
absent and the segment reads `Context: Ready`. The percentage is the authoritative figure. When the payload omits
`context_window_size`, the segment prints the used figure alone instead of dividing it by an assumed window, which would
print a ratio that contradicts the bar next to it.

Two rate-limit gauges follow, `5h` and `7d`, from `rate_limits.five_hour` and `rate_limits.seven_day`. A Claude.ai Pro
or Max session includes them; with API-key billing they are absent and the gauges disappear. Each gauge has its own
color and its own `↻` countdown to the reset. After that reset, the payload keeps the pre-reset figure until an API
response refreshes it, so the script dims the gauge and marks it `stale` instead of coloring a number it knows is wrong.

The branch comes from reading `.git/HEAD` directly instead of running `git`. The status line runs on every refresh, and
it has to work from a worktree or submodule, where `.git` is a file instead of a directory.

## Skills (`skills/`)

Two kinds of skill end up in `~/.claude/skills/`, and both are available in every project without a per-repo install:

- **Owned.** These are the directories in this folder, today `squad-env-branch`, `memory-curate`, `ship-draft` and
  `address-review`. The user writes and maintains them here, and `make claude` symlinks them.
- **Third-party.** `make skills` installs them with the [`skills`](https://github.com/vercel-labs/skills) CLI, as real
  directories copied from upstream: six from [`mattpocock/skills`](https://github.com/mattpocock/skills) and `unslop`
  from [`cursor/plugins`](https://github.com/cursor/plugins). The lists live in the `Makefile` (`skills_mattpocock`,
  `skills_cursor`), and the skill files are not in this repository.

This repository used to vendor the third-party skills byte for byte. After a sync, `git diff -- claude/skills` showed
the upstream changes, and nothing went live without review. That setup handled one upstream repository only. Taking a
single skill from a large repository, such as `unslop` out of the 47 in pstack, needed more setup than the skill
justified. The CLI picks skills by name from any repository. The cost is intended. Re-running `make skills` copies
upstream's current version into `~/.claude/skills/` with no review, so the safeguard is careful selection of what goes
into the lists, not reading every update. `~/.agents/.skill-lock.json` records what each machine got, and `make check`
reads it to confirm that each listed skill comes from the source its list names. `DISABLE_TELEMETRY=1` stops the CLI
from reporting installs. The pinned CLI version stops a new release from changing where or how the CLI writes skills
between two runs.

`improve-codebase-architecture` and `wait-what` carry `disable-model-invocation: true` upstream, so only a `/` command
runs them. `unslop` carries the flag too, although its own description says "Must always apply", so `make skills`
deletes the line from the installed copy. [cursor/plugins#379](https://github.com/cursor/plugins/pull/379) removes it
upstream and is still open. `memory-curate` sets the same flag for a different reason, explained below.

`improve-codebase-architecture` calls `domain-modeling` to update `GLOSSARY.md` and the ADRs as the user makes
decisions. `make skills` leaves `domain-modeling` out on purpose, because this setup keeps no glossary or ADRs. Those
updates therefore never happen, and the skill does the scan, the report and the grilling loop only. `make skills`
installs `codebase-design` because `improve-codebase-architecture` calls it for its architecture vocabulary.

### `memory-curate`

`memory-curate` rebuilds the current project's auto-memory directory (`~/.claude/projects/<project>/memory/`) from its
session transcripts. It exists because the built-in feature that would do this is not available. Claude Code includes a
local auto-dream pass, but `/memory` shows its `Auto-dream:` row only after a server-side capability check. On 2.1.260
(2026-09-04) the row is absent here, so auto-memory is on and auto-dream is not offered. Setting `autoDreamEnabled` in
`settings.json` would not help, because the binary reads that toggle behind the same check, so the key does nothing
until the rollout reaches the account. Do not add it. To check again, run `/memory` and look for the row instead of
reading settings.

The design comes from Anthropic's [Dreams](https://platform.claude.com/docs/en/managed-agents/dreams), which is a
different feature. Dreams is a Managed Agents API job over `memstore_…` stores and API sessions, in research preview
behind a request-access form. It never touches a local memory directory, so access to it would not curate anything here.
What carries over is its contract. It reads the store alongside past transcripts, writes a separate output, and leaves
the input untouched so the result can be reviewed or discarded. The skill writes a `memory.candidate-<ts>/` sibling
directory and swaps it in only after approval. `MEMORY.md` loads into every session, and a run that died halfway through
an in-place rewrite would break every session after it.

The skill takes input from real user turns only, extracted with `jq` (`.type == "user"`, no `isMeta`, no `isSidechain`,
string content, nothing starting with `<`). The last condition matters more than it looks. `isMeta` does not catch
`<command-name>`, `<command-message>`, `<local-command-stdout>` or `<task-notification>`, which all reach the transcript
as ordinary user turns. The filter exists to save cost. This project's 13 transcripts total 7.9 MB, and the filter
reduces them to 25 prompts. Without it, the skill would read the transcripts whole.

`disable-model-invocation: true` is on purpose here. The skill rewrites the directory that shapes every future session,
so it runs when you type `/memory-curate` and never on the model's own initiative. The cost is that you have to remember
the skill exists, and this section is that reminder.

## Plugins

`enabledPlugins` in `settings.json` makes these skills available in every project without a per-repo install.

- **`andrej-karpathy-skills`.** Behavioral guidelines (surgical changes, stated assumptions, verifiable success
  criteria) that counter over-engineering.
- **`claude-code-setup`.** Recommends hooks, subagents and skills for a given repo. Useful when setting up a new
  project.
- **`claude-md-management`.** Audits and improves `CLAUDE.md` files, so project memory keeps up with the code as it
  changes.
- **`claude-security`.** Multi-agent security scan of a repository. It returns verified findings as patch files to apply
  on demand, instead of editing in place.
- **`code-simplifier`.** A second cleanup pass after writing code, against accumulated complexity.
- **`context7`.** Fetches current library docs. It makes up for training data that lags behind recent framework
  versions.
- **`frontend-design`.** A frontend scaffolding skill with some visual polish, used occasionally.

## RTK (`RTK.md`)

[RTK](https://github.com/rtk-ai/rtk) is a CLI proxy that rewrites verbose commands into token-efficient equivalents, for
example `git status` into `rtk git status`. The PreToolUse hook is `rtk hook claude`, a subcommand of the binary that
`settings.json` calls directly. Nothing in this repo implements it.

Why use it:

- **Cost.** A `git log` or `find` dump can use thousands of tokens the model does not need. RTK cuts that noise before
  it reaches the model, with claimed savings of 60 to 90% on common dev operations.
- **Quality.** Less noise in context leaves more room for the actual problem, so each turn reasons better.
- **Transparency.** All rewrite rules live in the Rust binary, so the model does not need to know which commands rtk
  rewrites. `RTK.md`, imported through `@RTK.md` from `global.md`, only tells the model that rtk condenses command
  output, and when to fall back to `rtk proxy <cmd>`.

The hook reads `permissions` from `settings.json`. It rewrites an allowlisted command and allows it automatically,
passes a denied one through untouched, and rewrites anything else but still prompts. So the allowlist above decides
whether RTK saves a prompt as well as tokens.

Using the binary's hook instead of the shell hook that upstream also ships has a cost. The binary hook has no
`command -v rtk` guard, so on a machine without rtk it fails on every `Bash` call instead of doing nothing. `brew "rtk"`
is in the Brewfile. `rtk init --show`, `rtk hook check '<cmd>'` and `rtk verify` diagnose it.

`RTK.md` is not in this repository. `make claude` ends with `rtk init --global`, which writes it into `~/.claude/` from
the installed rtk. This is the same trade as for the third-party skills: no diff to review, and no vendoring step to
maintain. This repository used to vendor `RTK.md` and regenerate it in a sandboxed `HOME`, because `rtk init` also
patches `settings.json` and `global.md`. The sandbox is not needed now that both files already contain what rtk adds.
When rtk runs after the symlinks exist, it finds its hook and the `@RTK.md` import and changes neither file.
`rtk telemetry disable` runs first, so `rtk init` never asks for telemetry consent on a new machine. Telemetry stays off
here, as it does for the skills CLI.

## Command history (`hooks/command-history.sh`)

A PostToolUse hook on `Bash` appends every executed command to a daily JSONL file
(`~/.claude/command-history/YYYY-MM-DD.jsonl`) with timestamp, session id and cwd. The goal is to study agent behavior
over time. The hook records each command after the RTK rewrite, which is the command that actually ran. It always exits
0, so a logging failure can never disturb a session.

Retention reuses `cleanupPeriodDays` instead of declaring a second number. The log accompanies the transcripts, so
keeping it longer would only keep a record of sessions that no longer exist. The hook reads the key from `settings.json`
on each prune, so changing the setting moves both windows at once. It falls back to 90 when the key is absent or not a
plain integer. A PostToolUse hook fires on every `Bash` call, so the hook prunes at most once a day, using a
`.last-prune` stamp in the history directory. It writes the stamp before `find` runs, so a failed prune waits until the
next day instead of retrying on every command.
