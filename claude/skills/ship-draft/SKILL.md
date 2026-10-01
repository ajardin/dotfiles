---
name: ship-draft
description: Ship the current work as a draft pull request: branch if needed, commit, push, and open the PR filled from the repository's own PR template. Use when asked to commit and open a draft PR, to create the branch and the PR, or on /ship-draft.
argument-hint: "[--base <branch>] [ticket key or URL] [extra instructions]"
---

# Ship draft

Take the work in the current checkout to an open **draft** PR in one pass. A request to ship is
already the go-ahead. The draft itself is the review step, so publish without a preview round.

## Inputs

- **Base.** `--base <branch>` from `$ARGUMENTS`, otherwise the repository's default branch
  (`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`).
- **Conventions.** Read them from the repository, never from memory:
  - commit style: `git log --oneline -15`
  - PR titles, description language, ticket links:
    `gh pr list --author @me --state all --limit 5 --json title,body`
  - With no PR history yet, the commit log sets the style and the language.
- **Ticket.** A key or URL in `$ARGUMENTS` or in the conversation, otherwise a key in the branch
  name, but only when the recent PR bodies show that the repository links tickets (Jira, GitHub
  issues…). Link it the way those PRs do, as a full URL; with no ticket, there is no ticket
  section.
- **Template.** The first that exists of `.github/pull_request_template.md`,
  `pull_request_template.md`, `docs/pull_request_template.md`. With several templates under
  `.github/PULL_REQUEST_TEMPLATE/`, pick the one matching the change, and ask when none clearly
  does. With no template, use: summary, changes, testing, ticket.

## Steps

1. **Branch.** When the checkout is on the base branch, or you were asked to branch from it:
   `git fetch origin <base>`, then create a branch from `origin/<base>` named in the style of
   recent branches (`fix/…`, `feat/…`, `chore/…`, ticket key right after the prefix when there
   is one). Carry the uncommitted work across. Done when `git branch --show-current` names the
   new branch.
2. **Commit.** Stage only the files this task touched. When the tree also holds changes that
   belong to something else, list them and ask before going on. One commit per logical change,
   in the style of the log, no trailer. Done when `git status --short` shows nothing of this task.
3. **Check for an existing PR.** Run `gh pr list --head <branch> --json number,url`. If one
   exists, push, report its URL and stop there. Its description belongs to whoever edited it
   last, so leave it as it is.
4. **Push.** `git push -u origin <branch>`.
5. **Write the body.** Fill the template section by section, in the language of the recent PRs:
   - Replace every placeholder, and remove the HTML comments.
   - Drop the optional sections that do not apply to this change.
   - Under testing, state what this session actually ran (commands and outcome), or that
     nothing was run.
   - Tick every checklist item this session verified (tests added and green, docs updated,
     migration checked). Leave the rest unticked, and leave the items addressed to other roles
     (code owner, reviewer) to them.
   - Write the file to the scratchpad.
6. **Open.** Pick a title that follows the recent PR titles, or the commit subject when there are
   none, and pass it through a quoted heredoc rather than straight into double quotes, where the
   shell would run any `$(…)` or backtick in it:

   ```bash
   TITLE="$(cat <<'TITLE'
   <title>
   TITLE
   )"
   gh pr create --draft --base <base> --title "$TITLE" --body-file <file>
   ```
7. **Verify.** Straight away, run `gh pr view <n> --json body -q .body > <scratchpad>/check.md`
   and diff it against the file. Keep `check.md` in the scratchpad, never in the repository, where
   step 2 of the next run would commit it. The only difference allowed is the final newline. If more differs, the
   body was truncated, so publish it again with `gh pr edit <n> --body-file <file>` and diff again.

Done when the PR URL is returned and step 7's diff is clean. Close with the URL, the branch, the
commits, and any section of the template left empty with the reason.
