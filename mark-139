---
name: issue-close
description: Close an issue by number; optionally post a summary comment first. Dispatches by repo's `issues:` tracker.
---

Close one issue, identified by its number. Optionally post a summary
comment **before** closing it.

See `skills/lib/issue.md` for shared repo-config parsing, tracker
dispatch, and error wording. This file documents only what is specific
to `/issue-close`.

## Invocation

```text
/issue-close <issue-number> [--comment "summary"]
```

- `<issue-number>` — required. The issue number, with or without the
  repo's `issue-link-prefix` (`#42` and `42` are both accepted).
- `--comment "summary"` — optional. If present, post this string as a
  new comment on the issue **before** closing it. Use shell-style
  quoting; the value is passed verbatim to the tracker.

If `<issue-number>` is missing, prompt the user for it. Do not search
for "relevant issues" by title or by recent work — this skill closes
exactly the issue whose number was passed.

## Repo-config and tracker dispatch

Open with the standard repo-config read and `issues:` switch from
`skills/lib/issue.md` ("Repo-config parsing" and "Tracker dispatch").
This skill does **not** read the optional `github-project:` block —
closing an issue is a pure-issue operation and degrades fine without
project metadata.

## GitHub path (`issues: GitHub`)

1. If `--comment` was passed, post it first:

   ```bash
   gh issue comment <N> --body "<summary>"
   ```

   Surface any non-zero exit verbatim and stop — do **not** close the
   issue if the comment failed to post, otherwise the summary trail
   the user requested is missing.

2. Close the issue:

   ```bash
   gh issue close <N>
   ```

3. Report back:
   - The issue number and title.
   - Whether a comment was posted.
   - The new state (closed) and the URL.

## Jira path (`issues: Jira`)

Abort with the standard message from
`skills/lib/issue.md` → "Error message catalogue" → "Jira backend not
implemented":

> `issues: Jira` selected, but the Jira backend is not implemented.
> See #103.

Do not partially implement: no comment, no close, just the abort.

## Hard constraints

- **Never close an issue you weren't given by number.** No
  title-search, no "recent work" inference, no "find the relevant
  issues". The number is the only input that identifies the target.
- **Never close before commenting** when `--comment` was provided.
  Order is comment-then-close so the summary is preserved even if a
  later step fails.
- **Never use closing keywords in the comment body.** `closes`,
  `fixes`, `resolves` etc. inside a comment can cascade-close linked
  issues. If the user-supplied `--comment` contains them, pass it
  through verbatim — that's their call — but do not add such
  keywords yourself.
