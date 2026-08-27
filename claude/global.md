@RTK.md

# Database access

Never run SQL yourself — this includes the PhpStorm MCP database tools
(`execute_sql_query`, `preview_table_data`, `fetch_query_result`), CLI clients (`mysql`,
`psql`, dumps), and anything inside a container (`docker compose exec`). Reads count too:
the data is confidential.

Hand me the query in a code block instead and stop; I run it and paste back what matters.
Prefer answering from migrations, models and schema files — then no query is needed at all.

# Credential files

Never open a file holding credentials — `.env*`, `secrets/`, `config/jwt/`, `*.pem`/`*.key`,
`~/.aws`, `~/.ssh`. The `Read` deny rules bind one tool; the ban also covers `Grep`, `Bash`
(`cat`, `sed`, `grep`, `git show`) and any subagent you dispatch — pass it on. Partial reads
count, and a value that reaches you anyway is never echoed back.

Answer from what binds the variable: the config injecting it, the client consuming it,
`.dist` placeholders. Need the value? Name the path and stop; I look.
