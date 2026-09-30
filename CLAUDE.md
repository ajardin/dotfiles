# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal macOS dotfiles. Each top-level directory (`claude/`, `git/`, `homebrew/`, `terminal/`) is paired with a
`Makefile` target that deploys its contents into the user's home directory, almost always via `ln -sf` symlinks.
Editing a tracked file therefore takes effect immediately on the live system once the corresponding `make` target has
been run at least once — no copy step.

## Common commands

```bash
make help        # default target — list all targets with descriptions
make check       # verify every deployed symlink still points back into this repo, and every listed skill is installed
make claude      # run `skills`, symlink claude/ files into ~/.claude/, then generate RTK.md with `rtk init`
make git         # symlink git/ files into ~/ (also touches ~/.gitconfig-corporate)
make homebrew    # install Homebrew if missing, then `brew bundle install` from homebrew/Brewfile
make skills      # install or update the third-party skills in ~/.claude/skills/ through the skills CLI
make terminal    # symlink Ghostty config, fish config + functions, and Starship prompt
```

Targets are independent and idempotent (re-running re-creates symlinks). There is no test suite, linter, or CI.

## Deployment model and gotchas

- `git` target creates `~/.gitconfig-corporate` as an empty file via `touch` — this is intentional. `git/.gitconfig`
  includes it unconditionally and the `includeIf "gitdir:~/Projects/ajardin/"` block then layers
  `.gitconfig-opensource` on top for repos under that path. The corporate file stays out of the repo so work-specific
  `user.email` / signing config can live there without leaking.
- `claude` target symlinks `claude/global.md` to `~/.claude/CLAUDE.md` (Claude Code requires that filename in
  `~/.claude/`). The repo source is named `global.md` to avoid confusion with
  this per-repo `CLAUDE.md`. It imports `@RTK.md`, then locks replies to English whatever language the user writes in
  (explicitly *not* content written for others — a PR description or a review comment follows its own audience), and
  adds two standing bans: never run SQL directly, and never open a credential file (the ban is stated for `Grep`,
  `Bash` and subagents too, since the `Read` deny rules in `settings.json` only bind one tool). Between the language
  rule and those bans sit four working rules — `Evidence before claims`, `Scope`, `Handoffs`, `Third-party facts` —
  each derived from a logged failure in the May-September 2026 usage reports. `claude/README.md` records which
  incident produced which rule, so read it before reworking one.
- `claude` target refuses to run when any of its destinations in `~/.claude/` exists as a real file or directory
  instead of a symlink, and deploys nothing until it is removed. The symlinks are deliberately the way an outside
  edit becomes visible: a tool writing `~/.claude/settings.json` in place follows the link and lands in this
  repository, where `git diff` catches it. A tool writing it *atomically* (temp file + `rename`) replaces the link
  with a real file instead, and the unguarded `ln -sf` would then overwrite that with no diff to review — which is
  how the `codebase-memory-mcp` hook registrations were lost. The guard covers the same symlinks as `check`,
  owned skills included.
- `claude` target deploys one hook only (`command-history.sh`) and `rm -f`s the stale
  `~/.claude/hooks/rtk-rewrite.sh` left by earlier deployments, since RTK's hook is now the binary's own
  `rtk hook claude` and needs no file. Drop that `rm -f` once no machine still carries the old symlink.
- `claude` target also symlinks every directory under `claude/skills/` into `~/.claude/skills/`. These are **directory**
  symlinks, so the recipe uses `ln -sfn` (without `-n`, a second run would nest the new link inside the existing one).
  Adding a directory there and re-running `make claude` is enough to wire it up; `make check` picks it up through the
  same glob. That glob runs one way only: `check` iterates the repo and asks whether each skill has a symlink. For the
  real directories that the `skills` target installs, `check` works from the `Makefile` lists instead. It requires each
  listed skill to be a real directory with a `SKILL.md`, and uses `jq` to confirm that `~/.agents/.skill-lock.json`
  records it under the expected source. `check` cannot see a directory in `~/.claude/skills/` that is on neither list.
  Such a skill works on that machine and exists nowhere else, and `ls -la ~/.claude/skills/` is the only way to spot
  one.
- `claude/skills/` holds only the skills written and owned here, today `squad-env-branch`, `memory-curate`, `ship-draft`
  and `address-review`. The `skills` target installs the third-party ones. None of the owned skills hardcodes a path,
  repo, org or author. `squad-env-branch` derives them from `gh` and reads its squad roster from a per-repo
  `.claude/squad-env-branch.json`, asking for it when that file is missing; `memory-curate` takes the auto-memory
  directory from the `# Memory` section of the running system prompt, falling back to `CLAUDE_CONFIG_DIR` and the git
  toplevel, so a project-scoped `autoMemoryDirectory` is honoured without being restated.
- `skills` target installs the third-party skills with the `skills` CLI (`npx skills@1.7.0 add … --global --agent
  claude-code --copy`). It runs one `add` per upstream repo, each with its own list, and `skills_mattpocock` and
  `skills_cursor` at the top of the `Makefile` are the authoritative answer to "what is installed". The CLI finds a
  skill by name, so nobody needs to know its path upstream (`pstack/skills/unslop`). The skills land as real directories
  in `~/.claude/skills/`, not symlinks, and this repository does not version them. Re-running the target overwrites them
  with upstream's current `main`, so the same target installs and updates. Nobody reviews an upstream change before it
  goes live; the user accepts that cost in exchange for installing from several repositories.
  `~/.agents/.skill-lock.json` records what each machine has (source, path, content hash), and git does not track it
  either. The CLI also copies each skill's Codex-only `agents/` folder, which Claude Code does not use. The recipe sets
  `DISABLE_TELEMETRY=1` and pins the CLI version on purpose. Like rtk, the CLI resolves its target from
  `CLAUDE_CONFIG_DIR` in preference to `$HOME/.claude`. Before installing, the recipe deletes any symlink in
  `~/.claude/skills/` named after a skill that `claude/skills/` used to vendor, so the CLI never writes through a
  dangling link. Drop that loop once no machine still has such a link. After installing, the recipe deletes the
  `disable-model-invocation: true` line from `unslop`'s `SKILL.md`, so Claude can pick the skill on its own, as its
  description ("Must always apply") intends. [cursor/plugins#379](https://github.com/cursor/plugins/pull/379) makes the
  same change upstream. Once it merges, the `sed` line does nothing and can go.
- `claude` target depends on `skills`, so one `make claude` deploys everything under `~/.claude/`. Its last step runs
  `rtk init --global --auto-patch`, which writes `~/.claude/RTK.md` as a real file. Like the skills, that file is
  upstream's current output, untracked and unreviewed. The recipe runs rtk after the symlinks on purpose. rtk then finds
  its hook in `settings.json` and the `@RTK.md` import in `global.md`, reports both as present, and leaves both files
  byte-identical (checked twice in a row on rtk 0.50.0). Run before the symlinks exist, rtk would create its own real
  `settings.json` and `CLAUDE.md`. If a later rtk rewrites either file in place, the write lands in the repository and
  shows in `git diff`. If it writes atomically, it replaces the symlink and the guard refuses the next run. Either way,
  the change becomes visible. `RTK.md` used to live in `claude/RTK.md` behind a symlink. The recipe deletes that link
  before rtk runs, and `check` reports `link` if one remains. rtk resolves its target from `CLAUDE_CONFIG_DIR` in
  preference to `$HOME/.claude`. The recipe runs `rtk telemetry disable` just before `rtk init`. On a machine with no
  recorded answer, `init` would otherwise stop on an `Enable anonymous telemetry? [y/N]` prompt. The command also turns
  telemetry back off if someone enabled it, which is intended.
- `homebrew` target both installs Homebrew (if absent) **and** runs `brew bundle install` against
  `homebrew/Brewfile`. `Brewfile.lock.json` is written by Homebrew on bundle runs but is listed in `.gitignore` and
  deliberately not tracked.
- `terminal` target globs `terminal/fish/functions/*.fish` — adding a new file there and re-running `make terminal` is
  enough to wire it up. The Ghostty (`terminal/ghostty/config.ghostty` → `~/.config/ghostty/`) and Starship
  (`terminal/starship/starship.toml` → `~/.config/starship.toml`) symlinks are explicit, so a new file in either
  directory has to be added to the recipe by hand.
- The terminal files assume **Apple Silicon**: `config.fish` and `functions/sed.fish` call
  `/opt/homebrew/…` by absolute path rather than resolving Homebrew from `PATH`. Deliberate — the prefix is what
  bootstraps `PATH` in the first place — but it is the one thing to change on an Intel Mac, where it is
  `/usr/local/…`. In `config.fish` only the Starship prompt sits inside `status is-interactive`; the environment
  variables and `PATH` stay outside it, because fish scripts need them too.

## Claude Code integration

`claude/settings.json` is the user's global Claude Code config (symlinked to `~/.claude/settings.json`). Three parts
are load-bearing:

- **RTK PreToolUse hook** — `"command": "rtk hook claude"`, a subcommand of the `rtk` binary; nothing repo-side
  implements it. This is what `rtk init --global` installs on rtk ≥ 0.47. Upstream also ships a shell hook
  (`hooks/claude/rtk-rewrite.sh`) and its `hooks/` docs still describe it — that is the older path, not a reason to
  switch back. It has no "rtk missing → no-op" guard, so it depends on `brew "rtk"` from `make homebrew`. Diagnose
  with `rtk init --show`, `rtk hook check '<cmd>'` and `rtk verify`.
- **Command-history PostToolUse hook** (`claude/hooks/command-history.sh`) appends every executed `Bash` command to a
  daily JSONL file under `~/.claude/command-history/`, capturing it *after* the RTK rewrite — i.e. as actually
  executed. It also prunes its own files on the `cleanupPeriodDays` window read from `settings.json`, so the two
  retentions cannot drift apart; the prune is throttled to once a day because the hook runs on every `Bash` call. It
  always exits 0 so a logging failure can never disturb a session; preserve that when editing.
- **Status line** (`claude/statusline.py`) reads the status-line JSON from stdin and prints one `·`-separated line:
  model, effort level, context-usage bar, `5h` / `7d` rate-limit gauges, git branch. Missing data drops a segment and
  any uncaught failure prints the model name alone — a status line that throws leaves the prompt blank, so preserve
  that when editing. Each segment is also built behind its own `try`, so a malformed field costs only that segment;
  keep new segments inside the loop in `build_status` rather than appending to `parts` directly.

`enabledPlugins` and `extraKnownMarketplaces` in `settings.json` pin the user's plugin set — adding a plugin here is
the canonical way to enable it system-wide.

`claude/README.md` is the long-form rationale for every one of these choices (each `settings.json` key, the
status-line thresholds, why RTK, why each plugin). Read it before changing anything under `claude/`, and update it in
the same commit.

## Conventions for edits

- Keep `Makefile` recipes self-contained and use `${makefile_directory}` (already defined at the top) for absolute
  paths so targets work regardless of the user's `cwd`.
- Brewfile entries follow the pattern `# <one-line description>` immediately above each `brew`/`cask`. Match this when
  adding entries.
- Fish functions in `terminal/fish/functions/` follow the one-function-per-file convention required by fish's
  autoloader; the filename must match the function name.
- Every Markdown file wraps at 120 columns.
- Commit messages are a single imperative sentence in sentence case, no body, no prefix or scope tag ("Vendor upstream
  Claude skills and add a sync target"). No attribution trailer: `attribution` in `settings.json` is emptied on
  purpose, so strip any `Co-Authored-By` or session footer a tool tries to append.
