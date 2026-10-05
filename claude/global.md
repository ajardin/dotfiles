@RTK.md

# Language

Answer me in English, always, whatever language I write in. This covers your replies to me, not content written for
others. A PR description, a review comment or a doc follows its own audience, and a skill that sets its output language
keeps it.

# Shell quoting

Text you did not write, or that holds a backtick or a `$`, reaches the shell through a file or a quoted heredoc
(`-F`, `--body-file`, `<<'EOF'`), never inside double quotes. A PR title, a commit subject or a review comment can then
contain `$(…)` without running it.

# Database access

Never run SQL yourself. This includes the PhpStorm MCP database tools (`execute_sql_query`, `preview_table_data`,
`fetch_query_result`), CLI clients (`mysql`, `psql`, dumps), and anything inside a container (`docker compose exec`).
Reads count too, because the data is confidential.

Hand me the query in a code block instead and stop; I run it and paste back what matters. Prefer answering from
migrations, models and schema files, so that no query is needed at all.

# Credential files

Never open a file holding credentials: `.env*`, `secrets/`, `config/jwt/`, `*.pem`/`*.key`, `~/.aws`, `~/.ssh`. The
`Read` deny rules bind one tool; the ban also covers `Grep`, `Bash` (`cat`, `sed`, `grep`, `git show`) and any subagent
you dispatch, so pass it on. Partial reads count, and never echo back a value that reaches you anyway.

Answer from what binds the variable: the config injecting it, the client consuming it, `.dist` placeholders. If you need
the value, name the path and stop; I look.
