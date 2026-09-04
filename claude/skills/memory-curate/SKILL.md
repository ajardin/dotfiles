---
name: memory-curate
description: Rebuild this project's auto-memory directory from its session transcripts, into a candidate you review before adopting.
disable-model-invocation: true
argument-hint: "[what to focus on]"
---

# Memory Curate

Rebuild the auto-memory of the **current project** the way Anthropic's
[Dreams](https://platform.claude.com/docs/en/managed-agents/dreams) rebuilds a managed-agent memory
store: read the live memory directory alongside past session transcripts, then write a **candidate**
directory with duplicates merged, stale entries replaced by the latest value, and new insights
surfaced.

Dreams is an API feature over `memstore_…` stores and never touches a local memory directory; Claude
Code's own local equivalent is gated server-side and shows an `Auto-dream:` row in `/memory` once it
is available. This skill is the manual stand-in, and it borrows the one invariant that matters:

> The input store is never modified, so you can review the output and discard it if you don't like
> the result.

**The live directory is never written during a run.** Everything lands in the candidate; you adopt
it in Step 5 or throw it away.

## Argument

`$ARGUMENTS` steers what the pass synthesises — focus areas ("coding-style preferences only"),
content to preserve untouched, conventions to apply across the output. It shapes *synthesis*, not
text edits: an instruction targeting one line ("fix the count in the Brewfile entry") belongs in a
direct edit of that file instead.

## Configuration

The memory directory is the one named in the `# Memory` section of your own system prompt — read it
from there rather than reconstructing it, so a project-scoped `autoMemoryDirectory` is honoured for
free. With no such section, derive it:

```bash
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SLUG="$(git rev-parse --show-toplevel | tr '/' '-')"
MEMORY_DIR="$CONFIG_DIR/projects/$SLUG/memory"
SESSIONS_DIR="$(dirname "$MEMORY_DIR")"
CANDIDATE="$SESSIONS_DIR/memory.candidate-$(date +%Y-%m-%d-%H%M)"
```

---

## Step 0 — Preconditions

```bash
ls "$MEMORY_DIR"/*.md          # the live directory exists and holds memories
ls "$SESSIONS_DIR"/*.jsonl     # transcripts exist to mine
```

- **No memory directory** → stop and say so: there is nothing to curate.
- **No transcripts** → stop. Without sessions this is a reformat, not a curation.

Announce in one line: the memory directory, how many topic files it holds, how many transcripts are
in scope, and the candidate path about to be created.

---

## Step 1 — Orient

Read `MEMORY.md` and **every** topic file in the live directory. Build the working inventory: one
entry per file, carrying its `name`, `description`, `type`, and the claim it makes.

Done when every `.md` file in the directory appears in the inventory.

---

## Step 2 — Gather signal

Real user turns are the signal. Extract them from every transcript — never read a transcript whole,
they run to megabytes:

```bash
for f in "$SESSIONS_DIR"/*.jsonl; do
  echo "── $(basename "$f")"
  jq -r 'select(.type == "user" and (.isMeta | not) and (.isSidechain | not)
                and (.message.content | type == "string")
                and (.message.content | startswith("<") | not))
         | "[\(.timestamp[0:10])] \(.message.content)"' "$f" 2> /dev/null
done
```

`isMeta` drops harness injections and `isSidechain` drops subagent turns, but four wrappers still
arrive as ordinary user turns — `<command-name>`, `<command-message>`, `<local-command-stdout>` and
`<task-notification>` — so the leading-`<` test drops the class rather than the four names. What
survives is what the user actually typed. A genuine prompt opening on `<` goes with them; when the
extraction looks thin against the session count, re-run without that clause and read the difference.

Read the extraction and mark, with its date:

- **Corrections** — the user telling you an approach was wrong, or confirming one as right.
- **Preferences** — how they want work done, stated once and expected to hold.
- **Decisions** — a choice made about the project that the code does not record.
- **Reversals** — a later turn contradicting an earlier one. The later date wins.

Skip anything the repository already answers: architecture, file paths, git history, and every rule
already written in a `CLAUDE.md`.

Done when every transcript is accounted for — each one either mined or reported as carrying no user
turns.

---

## Step 3 — Write the candidate

```bash
mkdir -p "$CANDIDATE"
```

Write the rebuilt memory into `$CANDIDATE`, one file per memory, in the format the `# Memory`
section of your system prompt specifies (frontmatter with `name`, `description`, `metadata.type`;
`**Why:**` and `**How to apply:**` for `feedback` and `project`; `[[name]]` links between related
memories). Then:

- **Merge** duplicates into the single file that states the claim best.
- **Replace** a stale claim with the latest value, and resolve a contradiction in favour of the more
  recent turn.
- **Absorb** signal from Step 2 that no existing memory covers.
- **Drop** a memory the transcripts show to be wrong, superseded, or derivable from the repository.
- **Absolute dates only** — a memory saying "yesterday" is worthless on the next read.
- **Leave `modified` alone**: Claude Code stamps that frontmatter field on write.

A memory holding a credential or an API key does not get written — transcripts carry whatever was
pasted into them. Keep the binding (the config, the consuming client, the path) and leave the value
out.

Rewrite `MEMORY.md` last, as a pure index: a `- [Title](file.md) — hook` line per memory, under 200
lines and 25KB, with the content living in the topic files. Every candidate file gets a line; no
line points at a file that is not there.

---

## Step 4 — Review

```bash
diff -ru "$MEMORY_DIR" "$CANDIDATE"
```

Present the diff as a table the user can rule on: one row per memory, its fate (kept / merged /
rewritten / added / dropped), and for anything but "kept" the turn that justifies it, dated. A drop
with no cited turn is a drop you have not earned.

Then **stop and ask**. Nothing is adopted without an answer.

---

## Step 5 — Adopt or discard

On approval, swap atomically — the live `MEMORY.md` loads into every session, so it is never left
half-written:

```bash
mv "$MEMORY_DIR" "$MEMORY_DIR.backup-$(date +%Y-%m-%d-%H%M)"
mv "$CANDIDATE" "$MEMORY_DIR"
```

Report the new file count, and name the backup path so it can be restored or deleted.

On refusal, leave both directories alone and say where the candidate sits, so it can be read again
later.
