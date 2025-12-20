---
name: committer
description: Generate Git commit messages in Semantic Commit format. Use when asked to write commit messages, format Semantic Commits, or summarize changes/diffs into a commit.
---

# Committer

## Follow Semantic Commit format

Use the exact header format:

type(scope): subject

Rules:

- Use a valid type (feat, fix, refactor, chore, etc.)
- Use a concise scope that matches the changed area
- Keep the subject lowercase and concise
- Keep the full header under 100 characters

## Write the body correctly

Rules:

- Insert one blank line between header and body
- Start every body line with "- " and a capitalized word
- Keep each line under 100 characters
- Keep bullets concise and group related changes

## Output and clarification rules

- Output only the commit message wrapped in an md fenced code block (```md)
- Do not include any additional text outside the code block
- If type, scope, or change summary is missing, ask a concise clarifying question and do not
  output a code block

## Example

```md
refactor(members): simplify otp purpose validation logic in requestOtp

- Merged duplicated member existence checks into a single query
- Reordered conditional logic for better readability
- Kept validation inline to avoid introducing an extra function
```

## Special rule for file processing

- When processing shell scripts, code files, or configuration files, read the entire file before
  commenting on or modifying it.
