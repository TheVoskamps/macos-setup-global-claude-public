---
name: issue-comment
description: Add a comment to an issue by number, with the body read from a file. Dispatches by repo's `issues:` tracker.
---

Post a single comment to one issue, identified by its number. The
comment body is read from a file path the caller provides — never
composed inline by this skill.

See `skills/lib/issue.md` for shared repo-config parsing, tracker
dispatch, and error wording. This file documents only what is specific
to `/issue-comment`.

## Invocation

```text
/issue-comment <issue-number> --body-file PATH
```

- `<issue-number>` — required. The issue number, with or without the
  repo's `issue-link-prefix` (`#42` and `42` are both accepted).
- `--body-file PATH` — required. Filesystem path (absolute or relative
  to the repo root) to a file whose contents are posted verbatim as
  the comment body. Markdown is supported; the file is passed through
  unchanged.

Both arguments are required. If either is missing, prompt the user
for it and stop — do **not** search for "the right issue" by title or
fall back to composing a body from context. The skill no longer
guesses targets.

If the file at `PATH` does not exist, is empty, or is unreadable,
abort with a clear error and stop. Do not post an empty comment.

## Repo-config and tracker dispatch

Open with the standard repo-config read and `issues:` switch from
`skills/lib/issue.md` ("Repo-config parsing" and "Tracker dispatch").
This skill does **not** read the optional `github-project:` block —
commenting is a pure-issue operation and degrades fine without
project metadata.

## GitHub path (`issues: GitHub`)

Run:

```bash
gh issue comment <N> --body-file <PATH>
```

`gh` returns the new comment's URL on success; surface it in the
report back along with the issue number and title. Surface any
non-zero exit verbatim.

## Jira path (`issues: Jira`)

Abort with the standard message from
`skills/lib/issue.md` → "Error message catalogue" → "Jira backend not
implemented":

> `issues: Jira` selected, but the Jira backend is not implemented.
> See #103.

Do not partially implement: no comment posted, just the abort.

## Hard constraints

- **Never comment on an issue you weren't given by number.** No
  title-search, no "find the right issue", no "recent work"
  inference. The number is the only input that identifies the
  target.
- **Never compose the body inline.** The body always comes from
  `--body-file`. If the caller wants to comment a short string, they
  write it to a file (a temp file under `.claude/tmp/` is fine) and
  pass that path. Keeping the body in a file makes the exact posted
  text reviewable and reproducible.
- **Never close the issue from this skill.** Closing is
  `/issue-close`'s job. If the caller wants comment-then-close,
  they invoke `/issue-close <N> --comment "..."` instead.
