---
name: issue-update
description: Update a single issue's title, body (replace/append/prepend), labels, or assignees in one invocation.
---

Update fields on a single existing issue: title, full body
replacement, additive body edits (append/prepend a line), label
add/remove, and assignee add/remove. One issue per invocation; loop
in conversation when editing multiple issues.

See `skills/lib/issue.md` for the shared GraphQL templates, tracker
dispatch, and error wording. This file documents only what is
specific to `/issue-update`.

## Invocation

```
/issue-update <N>
              [--title "..."]
              [--body-file PATH]
              [--append "line to append"]
              [--prepend "line to prepend"]
              [--add-labels a,b] [--remove-labels a,b]
              [--add-assignees u1] [--remove-assignees u2]
```

- `<N>` (required): issue number in the current repo.
- `--title` (optional): replace the title.
- `--body-file` (optional): full-replace the body with the contents of
  the given file.
- `--append` (optional): append one line to the current body. Multiple
  `--append` flags concatenate in CLI order, each on its own line.
- `--prepend` (optional): prepend one line to the current body.
  Multiple `--prepend` flags stack in CLI order; the first `--prepend`
  ends up as the first line.
- `--add-labels` / `--remove-labels` (optional): comma-separated label
  names to add or remove.
- `--add-assignees` / `--remove-assignees` (optional): comma-separated
  GitHub usernames to add or remove.

At least one update flag must be passed. If none are present, abort
with a short usage reminder.

## Flag compatibility

- `--body-file` is **mutually exclusive** with `--append` and
  `--prepend`. A full replace makes line-additive edits ambiguous.
  Passing both aborts with:

  > `--body-file` cannot be combined with `--append` or `--prepend`
  > (full-replace vs. line-additive). Run them in separate
  > invocations.

- All other flag combinations are allowed and are applied in a single
  invocation.

## Tracker dispatch

Apply the standard `issues:` switch from `skills/lib/issue.md`. Jira
aborts with the shared message.

## Execution (GitHub backend)

1. **Fetch current body** if `--append` or `--prepend` was passed.
   Use `gh issue view <N> --json body --jq .body`. Do not fetch when
   only `--body-file` is in play — the new body is the file contents
   verbatim and the current body is irrelevant.

2. **Compute the new body**:
   - If `--body-file`: read the file. That's the new body.
   - Else if `--append` and/or `--prepend`: start from the current
     body. Prepend lines (in CLI order) to the front, each followed
     by `\n`. Append lines (in CLI order) to the end, each preceded
     by `\n`. Preserve the existing body's trailing newline behavior.
   - Else: skip the body update entirely.

3. **Apply edits via `gh issue edit`** in one call where possible.
   `gh issue edit` supports `--title`, `--body-file`, `--add-label`,
   `--remove-label`, `--add-assignee`, and `--remove-assignee` in a
   single invocation:

   ```bash
   gh issue edit <N> \
     [--title "<new-title>"] \
     [--body-file <path-or-tmpfile>] \
     [--add-label "<comma-list>"] \
     [--remove-label "<comma-list>"] \
     [--add-assignee "<comma-list>"] \
     [--remove-assignee "<comma-list>"]
   ```

   When the computed new body comes from `--append`/`--prepend`, write
   it to a temp file under `.claude/tmp/issue-update-<N>/` and pass
   `--body-file <tmpfile>`. Do **not** use `--body "..."` for
   multi-line content — Markdown and shell quoting interact badly.
   Clean the tempfile up on success; leave it in place on failure for
   inspection.

   Build the invocation only from flags the user actually passed. Do
   not pass empty values.

4. **Issue not found**: if `gh issue edit` returns
   `could not resolve to an Issue`, emit the "Issue not found"
   error from the catalogue in `skills/lib/issue.md` and abort.

## Output

Print a single line per field that changed:

```
Updated issue #<N>:
  title:           <new title>
  body:            replaced (<lines> lines)              # --body-file
  body:            appended <N> line(s), prepended <M> line(s)
  labels added:    a, b
  labels removed:  c
  assignees added: u1
  assignees removed: u2
```

Then a blank line and the issue URL.

Skip fields that didn't change. When only one flag was passed, only
one summary line shows.
