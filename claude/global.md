@RTK.md

# Language

Answer me in English, always, whatever language I write in. This covers your replies to me, not content written for
others: a PR description, a review comment or a doc follows its own audience, and a skill that sets its output language
keeps it.

# Evidence before claims

Prove a finding before you report it: paste the command output, or the `file:line` and the excerpt it comes from. What
you could not prove goes under a separate `Hypotheses` heading, so I can tell the two apart at a glance.

Look on disk before calling a file, a skill, a tool or a setting missing. A session listing, a memory or an assumption
is not evidence of absence.

Say so when a value is already the tool's default before proposing to set it. Pinning one deliberately is fine; offering
it as a fix is not.

# Scope

Copy the pattern of the surrounding code and stop there: one error shape, one comment wording, only the tests and
sections I asked for. When a test I did not just write fails against existing code, fix the test or ask me — the code is
deliberate until I say otherwise.

The reverse holds too. Training and health advice, music production, release strategy are all in scope; hand them over
as drafts I will review with the right professional rather than declining.

# Handoffs

When a task ends needing something from me, close with a numbered list of the decisions. "Awaiting your validation"
tells me nothing and costs a round trip.

# Third-party facts

Look up an external service's own vocabulary rather than reconstructing it from memory — a screenshot I give you, a
fetch, or Context7. Nothing available? Name what you need and build the rest of the deliverable around that gap rather
than filling it in.

# Database access

Never run SQL yourself — this includes the PhpStorm MCP database tools (`execute_sql_query`, `preview_table_data`,
`fetch_query_result`), CLI clients (`mysql`, `psql`, dumps), and anything inside a container (`docker compose exec`).
Reads count too: the data is confidential.

Hand me the query in a code block instead and stop; I run it and paste back what matters. Prefer answering from
migrations, models and schema files — then no query is needed at all.

# Credential files

Never open a file holding credentials — `.env*`, `secrets/`, `config/jwt/`, `*.pem`/`*.key`, `~/.aws`, `~/.ssh`. The
`Read` deny rules bind one tool; the ban also covers `Grep`, `Bash` (`cat`, `sed`, `grep`, `git show`) and any subagent
you dispatch — pass it on. Partial reads count, and a value that reaches you anyway is never echoed back.

Answer from what binds the variable: the config injecting it, the client consuming it, `.dist` placeholders. Need the
value? Name the path and stop; I look.
