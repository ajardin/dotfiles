---
name: squad-env-branch
description: Prepare the branch to deploy on the squad environment. Stack every open non-draft PR of the squad on top of an up-to-date base branch, in the current repository, resolving conflicts by intent as they come. The branch stays local, nothing is pushed. Use when asked to prepare the squad environment branch, to integrate the team's open PRs, or on /squad-env-branch.
argument-hint: "[branch name]"
---

# Squad Env Branch

Build a throwaway local branch in the **current repository** that stacks every in-flight PR of the
squad, so the whole set can be deployed to the squad environment and tested together. Conflicts are
resolved **by intent** (read both sides, decide, log it). Nothing is pushed: the branch ends up
ready to inspect, and you decide what happens next.

## Argument

`%ARGUMENTS` may carry the name of the branch to create. Otherwise default to
`deploy/squad-<YYYY-MM-DD>`.

## Configuration

Everything except the roster comes from the environment, so there is nothing to keep in sync: the
authenticated account is `gh api user -q .login`, the repository and its owner are `gh repo view
--json nameWithOwner`, and the base branch defaults to the repository's own default branch
(`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`).

**The roster is the one thing that has to be declared**, and it lives in
`.claude/squad-env-branch.json` at the root of the current repository:

```json
{ "authors": ["alice", "bob", "carol", "dave"] }
```

- `authors` — GitHub logins to integrate. Authoritative when present.
- `team` — instead of `authors`, a GitHub team whose members form the roster, as `org/slug` or a
  bare `slug` taken in the repository's owner org.
- `base` — optional, overriding the default branch for a repository that deploys off something else.

Resolve both into the variables the rest of this skill uses:

```bash
CONFIG=".claude/squad-env-branch.json"
AUTHORS="$(jq -r '.authors[]?' "$CONFIG" 2> /dev/null | tr '\n' ' ')"
TEAM="$(jq -r '.team // empty' "$CONFIG" 2> /dev/null)"
[ -n "$AUTHORS" ] || [ -z "$TEAM" ] || AUTHORS="$(gh api "/orgs/${TEAM%/*}/teams/${TEAM##*/}/members" -q '.[].login' | tr '\n' ' ')"
BASE="$(jq -r '.base // empty' "$CONFIG" 2> /dev/null)"
BASE="${BASE:-$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)}"
```

A bare `slug` leaves `${TEAM%/*}` equal to the slug itself, so pass the owner org from
`gh repo view --json owner -q .owner.login` in that case.

**With an empty `$AUTHORS`**, ask which logins to integrate, run the flow with the answer, then
offer to write the file so the next run in this repository needs no question. Never guess a roster
from the repository's contributors or from a team that merely looks close: integrating the wrong
author's PRs into a deployment branch is a silent, expensive error.

---

## Step 0 — Preconditions

Check everything before touching the repository. On any failure, **stop** and say which one.

```bash
git rev-parse --is-inside-work-tree                   # we are inside a git repository
gh auth status                                        # gh is authenticated
gh repo view --json nameWithOwner -q .nameWithOwner   # current repo, to display
git status --porcelain                                # MUST be empty (clean working tree)
```

- **Dirty working tree** (`git status --porcelain` non-empty) → stop and ask the user to commit or
  stash first. Their changes are theirs to move; leave them alone.
- **gh failing** → report it and stop.
- **No roster** resolvable (see Configuration) → ask for it before going any further.

Announce in one line: current repo, resolved roster, base branch, and the name of the branch about
to be created.

---

## Step 1 — Create the branch from an up-to-date base

```bash
git fetch origin "$BASE"                       # BASE resolved in Configuration
BRANCH="deploy/squad-$(date +%Y-%m-%d)"        # or the value passed as an argument
```

- If `BRANCH` already exists (`git rev-parse --verify --quiet "$BRANCH"`), it is probably a previous
  integration: offer either a time suffix (`deploy/squad-<date>-<HHhMM>`) or deleting the old one
  (`git branch -D`), and **ask** before deleting.
- Branch from **`origin/$BASE`**, never from the local base branch, which may lag behind:

```bash
git switch --create "$BRANCH" "origin/$BASE"
```

---

## Step 2 — List the PRs to integrate

Every **open**, **non-draft** PR authored by a roster member in the current repo, **whatever their
base** (deliberate choice). The step is done when every such PR is accounted for, each one either
queued for merge or explicitly reported as skipped.

```bash
for a in $AUTHORS; do                          # the roster resolved above
  gh pr list --state open --limit 200 --search "draft:false author:$a" \
    --json number,title,url,author,isDraft,headRefName,baseRefName,createdAt
done | jq -s '
  (add | unique_by(.number)) as $prs
  | ($prs | map({(.headRefName): .number}) | add) as $byHead
  | $prs
  | map(. + {stackedOn: ($byHead[.baseRefName] // null)})
  | sort_by(.createdAt)
'
```

- ⚠️ **One query per author, never a multiple `author:`.** GitHub combines several `author:`
  qualifiers with **AND**, so `author:x author:y` returns nothing. Each author is queried
  separately, then `jq -s` merges and dedupes by number. `draft:false` drops the drafts.
- The `jq` annotates each PR with **`stackedOn`**: the number of the PR in the set whose **head** is
  this PR's **base**, or `null` when its base is `$BASE` or a branch outside the set. That field is
  what materialises the stacks.
- Display the retained list **in topological merge order** (number, author, title, base,
  `stackedOn`) **before** merging anything, so the user sees what is coming and in which order.
  With no PR at all, say so and stop: the branch is still `origin/$BASE`.

### Merge order — PR stacks (`stackedOn`)

A stack `$BASE ← feat/A ← feat/B` means PR `feat/B` has PR `feat/A`'s **head** as its **base**, so
the parent merges before the child. Order them by topological sort (Kahn):

1. Roots first: the PRs with `stackedOn = null`, sorted among themselves by ascending `createdAt`.
2. Then, each round, add the PRs whose parent (`stackedOn`) is **already placed**, ascending
   `createdAt` breaking ties. Repeat until exhausted.
3. A stack `A ← B ← C` gives `A, B, C`. A parent with several children places them all after it.
4. Readability preference: keep a stack **contiguous** (merge `A, B, C` in a row before starting
   another root) so related deltas follow each other. Comfort only. The hard constraint stays:
   parent before child.

⚠️ **Chronology alone is wrong.** In real data a child PR can be **created before** its parent
(rebase, branch recreation), so sorting by `createdAt` alone would merge the child first. That is
exactly what `stackedOn` fixes: it is the hard constraint, `createdAt` only breaks ties between
independent PRs.

A child's branch **already contains** its parent's commits, so merging parent then child means each
merge carries only that PR's **own delta**: minimal merges, conflicts attributed to the right PR.
Reversed, the parent would surface as "already integrated" once the child was in.

**Edge case** to **note** in the report rather than exclude: `stackedOn = null` **but**
`baseRefName != $BASE` means the base is a branch outside the set (a non-member's PR, or a parent
that is a draft and therefore excluded). Merging the head still brings that base's commits along, so
flag it under "Watch out".

---

## Step 3 — Merge the PRs one by one

Work through the PRs **in the topological order computed in Step 2**, a child never before the PR it
is stacked on. Every listed PR ends with a journal entry (status, plus any conflicts resolved); those
entries are what Step 5 reports.

For a PR `#N` titled `<title>`, authored by `@<author>`:

```bash
git fetch origin "pull/N/head"                 # PR head, fork-safe, no local ref
git merge --no-ff -m "Merge PR #N — <title> (@<author>)" FETCH_HEAD
```

Read the merge result:

- **Success (exit 0)** → clean merge. Log ✅.
- **"Already up to date"** → the PR is already contained in the branch (merged into the base branch,
  for instance). Log ⏭️ "already integrated" and move on.
- **Conflict (non-zero exit, "CONFLICT" in the output)** → go to Step 4 for this PR, then come back
  here for the next one.
- **Any other error** (head not found, fetch failed…) → log ❌ with the message, run `git merge
  --abort` if a merge is in progress, and **carry on** with the next PR rather than stopping the run.

The branch stays local: no `git push`, no PR opened.

---

## Step 4 — Resolve conflicts by intent

On a conflicted merge, resolve file by file, understanding what each side was trying to do.

1. List the conflicted files:

   ```bash
   git diff --name-only --diff-filter=U
   ```

2. **Read** each file and work through the `<<<<<<<` / `=======` / `>>>>>>>` markers:
   - `<<<<<<< HEAD` ("ours") is the deployment branch as it stands: the base branch plus the PRs
     already integrated.
   - `>>>>>>> FETCH_HEAD` ("theirs") is the incoming PR.
   - Resolve on meaning:
     - **Additive and independent** changes (imports, new methods, new config/routes/services
       entries) → **keep both**.
     - A genuine divergence on the same logic → keep the **semantically correct** version. The
       incoming PR's intent usually wins, unless it regresses something already integrated. On real
       doubt, make a best-effort call **and surface it** in the report for human review.
   - Leave a coherent file that compiles or parses, with every conflict marker gone.

3. **Lock and generated files** (`composer.lock`, `pnpm-lock.yaml`, `package-lock.json`,
   `yarn.lock`, generated migrations, snapshots…): resolve these by regenerating rather than editing
   markers. Use the repo's tooling when it is available (`composer update --lock`, `pnpm install`…);
   otherwise take the incoming version and flag it **"to regenerate"** in the report.

4. Mark resolved, then close the merge:

   ```bash
   git add <resolved files>
   git commit --no-edit                         # closes the merge, keeping the message
   ```

5. Log ⚠️ for this PR: the conflicted files resolved, marking with 🔎 every one whose resolution was
   a judgement call worth re-reading.

---

## Step 5 — Final report

Write the summary straight into the chat:

```markdown
# 🚀 Deployment branch ready — `<BRANCH>`

Repo: `<owner/repo>` · Base: `origin/<base>` (up to date) · PRs integrated: X / Y

## Integrations
- ✅ `#17822` feat(...) — @alice — clean merge
- ⚠️ `#17790` fix(...) — @bob — conflicts resolved: `src/Foo.php` 🔎, `src/Bar.php`
- ⏭️ `#17780` chore(...) — @carol — already integrated (nothing to merge)
- ❌ `#17801` feat(...) — @dave — failed: <reason> (not integrated)

## To review (judgement calls 🔎)
- `#17790` `src/Foo.php` — <one line: the decision taken and why>

## Watch out
- `#176xx` targeted `develop`, not the base branch — commits possibly out of scope.
- `composer.lock` taken from the incoming PR — **regenerate it** before deploying.

## Next
- Inspect / test the branch: `git switch <BRANCH>`, then run the QA / the tests.
- Nothing was pushed. To publish: `git push -u origin <BRANCH>` (your call).
```

Report only what actually ran: every line traces back to a Step 3 or Step 4 journal entry. Direct
tone, no filler.
