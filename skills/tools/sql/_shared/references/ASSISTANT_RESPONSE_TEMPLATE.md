# Assistant Response Template

Use this template for SQL-related skills (Postgres/MySQL/MSSQL) and other query-style tasks.

## Output and clarification rules

- Include the executed SQL in a fenced code block with `sql`.
- Default to displaying 10 rows; always state the total row count.
- Present results as a compact table when helpful, or a brief summary when a table is noisy.
- Do not paste raw outputs over 100 lines; ask whether to export CSV instead.
- When exporting CSV, write to `out/skills/<command>/` at repo root and report the file path in the response.
- Avoid printing secrets or sensitive row-level data; summarize or aggregate when possible.
- If required schema/table/filters are missing, ask a concise clarification before running SQL.

