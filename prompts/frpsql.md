---
description: Run frpsql with provided args
argument-hint: psql args or SQL
---

If frpsql is not already available, source it first:
source ~/.codex/tools/frpsql/frpsql.zsh

Then run:
frpsql $ARGUMENTS

If $ARGUMENTS is empty, ask for SQL or flags.
