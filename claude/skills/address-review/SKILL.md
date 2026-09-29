---
name: address-review
description: Address the review comments on a pull request: collect the unresolved threads, judge each one, then implement the points the user picks. Use when asked to handle a colleague's feedback or review comments, when given a PR discussion link, or on /address-review.
argument-hint: "[PR number | PR URL | discussion URL] [extra instructions]"
---

# Address Review

Turn a reviewer's threads into changes, point by point, with the user deciding at every
**gate**. GitHub is the user's voice: the skill writes reply drafts, and only the user publishes
them. The one write this skill makes on GitHub is resolving the threads the user names.

## Scope

- A discussion URL (`…#discussion_r<id>`) scopes the run to that single thread.
- A PR number or URL, or nothing (the current branch's PR, from `gh pr view --json number`),
  scopes it to every unresolved thread.

## Steps

1. **Collect.** Fetch the threads with
   `gh api graphql` on `repository.pullRequest(number:).reviewThreads`, keeping `id`,
   `isResolved`, `isOutdated`, `path`, `line` and `comments { author { login } body url }`.
   Keep the unresolved threads opened by someone other than you (`gh api user -q .login`), bots
   included, on the same footing as people. A discussion URL matches the comment whose `url`
   ends with the same `#discussion_r<id>`. Add the review bodies and top-level comments that ask
   for something (`gh pr view --json reviews,comments`). Done when every unresolved thread of the
   scope is accounted for.
2. **Triage.** For each point, read the code it targets, as it is now (a thread marked outdated
   may already be handled). Present one table: `#`, author, `file:line`, the request in one line,
   your **verdict** (agree / partly / disagree), the evidence (`file:line` and an excerpt, or the
   project rule it relies on), and the **cost** (trivial / needs a decision). Give options for
   every point marked "needs a decision". Done when every collected point is a row. Then stop:
   this is the first gate.
3. **Implement** every point the user picks, in the order given. Once all of them are in, run the
   tests covering the code they touch, a single run for the whole batch. Report the diff point by
   point, then the test outcome. Then stop at the gate. Commit, push and resolve each wait for the
   user's word, as follows:
   - **Commit**: one commit per point, in the style of `git log --oneline -15`, or an amend
     into the previous commit when asked. Stage each point on its own: whole files, or a hunk
     patch through `git apply --cached` when two points share a file. Points whose hunks
     overlap go in one commit, named as such.
   - **Push**: `git push`. Force-push only after an amend the user asked for, with
     `--force-with-lease`.
   - **Resolve**: `resolveReviewThread(input: {threadId})` on the threads the user names, and
     only after the push that carries the fix.
4. **Draft replies** for the points the user will answer themselves (a disagreement, a
   decision, a question back). Write them to the scratchpad, one section per thread, headed by
   the thread's URL, in the language of the thread. Open the file in the IDE when an IDE tool is
   available.

Done when every picked point is implemented and tested, or explicitly set aside, and every
thread in scope ends as one of: resolved, a reply draft waiting for the user, or left open on the
user's call. Close with that list, one line per thread with its URL.
