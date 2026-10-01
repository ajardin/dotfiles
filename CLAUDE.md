# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal macOS dotfiles. Each top-level directory (`claude/`, `git/`, `homebrew/`, `terminal/`) has a `Makefile` target
that deploys its contents into the user's home directory, almost always as `ln -sf` symlinks. Once that target has run,
an edit to a tracked file takes effect on the live system at once, with no copy step.

## Common commands

```bash
make help        # default target, lists all targets with descriptions
make check       # verify every deployed symlink still points back into this repo, and every listed skill is installed
make claude      # run `skills`, symlink claude/ files into ~/.claude/, then generate RTK.md with `rtk init`
make git         # symlink git/ files into ~/ (also touches ~/.gitconfig-corporate)
make homebrew    # install Homebrew if missing, then `brew bundle install` from homebrew/Brewfile
make skills      # install or update the third-party skills in ~/.claude/skills/ through the skills CLI
make terminal    # symlink Ghostty config, fish config and functions, and Starship prompt
```

Targets are idempotent. Running one again re-creates its symlinks. `make claude` also runs `skills`, which reinstalls
the third-party skills from upstream's current version, without review. There is no test suite, linter or CI.

## Deployment model and gotchas

- `git` target creates `~/.gitconfig-corporate` as an empty file with `touch`, on purpose. `git/.gitconfig` always
  includes it, and its `includeIf "gitdir:~/Projects/ajardin/"` block then adds `.gitconfig-opensource` on top for repos
  under that path. The corporate file stays out of the repo, so work-specific `user.email` and signing config can live
  there without leaking.
- `claude` target symlinks `claude/global.md` to `~/.claude/CLAUDE.md`, because Claude Code requires that filename in
  `~/.claude/`. The repo source is named `global.md` to avoid confusion with this per-repo `CLAUDE.md`. It imports
  `@RTK.md` and makes Claude reply in English whatever language the user writes in. That rule excludes content written
  for others, since a PR description or a review comment follows its own audience. It also sets two standing bans: never
  run SQL directly, and never open a credential file. The credential ban names `Grep`, `Bash` and subagents too, because
  the `Read` deny rules in `settings.json` only bind one tool. Between the language rule and those bans, the file lists
  four working rules: `Evidence before claims`, `Scope`, `Handoffs` and `Third-party facts`. Each comes from a logged
  failure in the May to September 2026 usage reports. `claude/README.md` records which incident produced which rule, so
  read it before reworking one.
- `claude` target refuses to run when any of its destinations in `~/.claude/` is a real file or directory instead of a
  symlink, and deploys nothing until someone removes it. The symlinks are how an outside edit becomes visible. A tool
  that writes `~/.claude/settings.json` in place follows the link into this repository, where `git diff` shows the
  change. A tool that writes it atomically (temp file and `rename`) replaces the link with a real file instead. Without
  the guard, `ln -sf` would then overwrite that file with no diff to review, which is how the `codebase-memory-mcp` hook
  registrations were lost. The guard covers the same symlinks as `check`, owned skills included.
- `claude` target deploys one hook only (`command-history.sh`). It also deletes the stale
  `~/.claude/hooks/rtk-rewrite.sh` left by earlier deployments, because RTK's hook is now the binary's own
  `rtk hook claude` and needs no file. Drop that `rm -f` once no machine still has the old symlink.
- `claude` target also symlinks every directory under `claude/skills/` into `~/.claude/skills/`. These are directory
  symlinks, so the recipe uses `ln -sfn`. Without `-n`, a second run would nest the new link inside the existing one. To
  wire up a new skill, add a directory there and run `make claude` again; `make check` finds it through the same glob.
  That glob only checks in one direction. `check` iterates the repo and asks whether each skill has a symlink. For the
  real directories that the `skills` target installs, `check` works from the `Makefile` lists instead. It requires each
  listed skill to be a real directory with a `SKILL.md`, and uses `jq` to confirm that `~/.agents/.skill-lock.json`
  records it under the expected source. `check` cannot see a directory in `~/.claude/skills/` that is on neither list.
  Such a skill works on that machine and exists nowhere else, and `ls -la ~/.claude/skills/` is the only way to spot
  one.
- `claude/skills/` holds only the skills written and owned here, today `squad-env-branch`, `memory-curate`, `ship-draft`
  and `address-review`. The `skills` target installs the third-party ones. None of the owned skills hardcodes a path,
  repo, org or author. `squad-env-branch` derives them from `gh` and reads its squad roster from a per-repo
  `.claude/squad-env-branch.json`, asking for it when that file is missing. `memory-curate` takes the auto-memory
  directory from the `# Memory` section of the running system prompt, falling back to `CLAUDE_CONFIG_DIR` and the git
  toplevel, so it honours a project-scoped `autoMemoryDirectory` without restating it.
- `skills` target installs the third-party skills with the `skills` CLI
  (`npx skills@1.7.0 add … --global --agent claude-code --copy`). It runs one `add` per upstream repo, each with its own
  list, and `skills_mattpocock` and `skills_cursor` at the top of the `Makefile` are the authoritative answer to "what
  is installed". The CLI finds a skill by name, so nobody needs to know its path upstream (`pstack/skills/unslop`). The
  skills land as real directories in `~/.claude/skills/`, not symlinks, and this repository does not version them.
  Re-running the target overwrites them with upstream's current `main`, so the same target installs and updates. Nobody
  reviews an upstream change before it goes live; the user accepts that cost in exchange for installing from several
  repositories. `~/.agents/.skill-lock.json` records what each machine has (source, path, content hash), and git does
  not track it either. The CLI also copies each skill's Codex-only `agents/` folder, which Claude Code does not use. The
  recipe sets `DISABLE_TELEMETRY=1` and pins the CLI version on purpose. Like rtk, the CLI resolves its target from
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
- `homebrew` target installs Homebrew if it is missing, and also runs `brew bundle install` against `homebrew/Brewfile`.
  Homebrew writes `Brewfile.lock.json` on bundle runs. `.gitignore` lists it on purpose, so git does not track it.
- `terminal` target globs `terminal/fish/functions/*.fish`, so adding a new file there and running `make terminal` again
  is enough to wire it up. The Ghostty (`terminal/ghostty/config.ghostty` to `~/.config/ghostty/`) and Starship
  (`terminal/starship/starship.toml` to `~/.config/starship.toml`) symlinks are explicit, so a new file in either
  directory needs a new line in the recipe.
- The terminal files assume Apple Silicon. `config.fish` and `functions/sed.fish` call `/opt/homebrew/…` by absolute
  path instead of resolving Homebrew from `PATH`. This is on purpose, because that prefix is what sets up `PATH` in the
  first place. It is the one thing to change on an Intel Mac, where the prefix is `/usr/local/…`. In `config.fish`, only
  the Starship prompt sits inside `status is-interactive`. The environment variables and `PATH` stay outside it, because
  fish scripts need them too.

## Claude Code integration

`claude/settings.json` is the user's global Claude Code config, symlinked to `~/.claude/settings.json`. Three parts of
it need care:

- **RTK PreToolUse hook.** Its command is `rtk hook claude`, a subcommand of the `rtk` binary; nothing in this repo
  implements it. `rtk init --global` installs the hook this way on rtk 0.47 and later. Upstream also ships a shell hook
  (`hooks/claude/rtk-rewrite.sh`), and its `hooks/` docs still describe it. That is the older approach, not a reason to
  switch back. The binary hook has no guard that turns it into a no-op when rtk is missing, so it depends on
  `brew "rtk"` from `make homebrew`. Diagnose it with `rtk init --show`, `rtk hook check '<cmd>'` and `rtk verify`.
- **Command-history PostToolUse hook.** `claude/hooks/command-history.sh` appends every executed `Bash` command to a
  daily JSONL file under `~/.claude/command-history/`. It records the command after the RTK rewrite, which is the
  command that actually ran. It also deletes its own files older than the `cleanupPeriodDays` window it reads from
  `settings.json`, so the transcripts and the log follow the same setting. It runs that cleanup at most once a day,
  because the hook runs on every `Bash` call. It always exits 0, so a logging failure can never disturb a session; keep
  that when editing.
- **Status line.** `claude/statusline.py` reads the status-line JSON from stdin and prints one line of segments
  separated by `·`: model, effort level, context-usage bar, `5h` and `7d` rate-limit gauges, and git branch. Missing
  data drops a segment, and any uncaught failure prints the model name alone, because a status line that throws leaves
  the prompt blank. Keep that behaviour when editing. The script also builds each segment inside its own `try`, so a
  malformed field costs only that segment. Add new segments inside the loop in `build_status` instead of appending to
  `parts` directly.

`enabledPlugins` and `extraKnownMarketplaces` in `settings.json` pin the user's plugin set. Adding a plugin there is the
standard way to enable it everywhere.

`claude/README.md` explains every one of these choices in detail: each `settings.json` key, the status-line thresholds,
why RTK, why each plugin. Read it before changing anything under `claude/`, and update it in the same commit.

## Conventions for edits

- Keep `Makefile` recipes self-contained, and use `${makefile_directory}`, defined at the top, for absolute paths, so
  targets work from any `cwd`.
- Brewfile entries follow the pattern `# <one-line description>` immediately above each `brew` or `cask`. Match it when
  adding entries.
- Fish functions in `terminal/fish/functions/` follow the one-function-per-file convention that fish's autoloader
  requires; the filename must match the function name.
- Every Markdown file wraps at 120 columns.
- Commit messages are a single imperative sentence in sentence case, with no body and no prefix or scope tag ("Vendor
  upstream Claude skills and add a sync target"). Add no attribution trailer. `attribution` in `settings.json` is empty
  on purpose, so strip any `Co-Authored-By` or session footer a tool tries to append.
