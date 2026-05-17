---
name: issue-set-importance
description: Set the importance (1-9 number field) on a single issue's project board entry.
---

Set the importance number on a single issue's entry in the configured
GitHub Project V2 board. Importance is the number field whose ID is
stored under `github-project.fields.importance` in
`.claude/rules/repo-config.md`.

See `skills/lib/issue.md` for the shared GraphQL templates, tracker
dispatch, error wording, and graceful-degradation rules. This file
documents only what is specific to `/issue-set-importance`.

## Invocation

```text
/issue-set-importance <issue-number> <1-9>
```

- `<issue-number>` (required): issue number in the current repo, with
  or without a leading `#`.
- `<1-9>` (required): integer between 1 and 9 inclusive. The command
  does not clamp; any of the three rejection cases below aborts with
  the "Slot value out of range" error from the catalogue in
  `skills/lib/issue.md` (with `<slot>` = `importance`,
  `<min>` = `1`, `<max>` = `9`):
  - **Non-integer input** — e.g. `3.5`, `three`, anything that does
    not parse as a base-10 integer.
  - **Out-of-range integer** — e.g. `0`, `10`, or any integer outside
    the closed interval `[1, 9]`.
  - **Empty or missing argument** — the verb requires the value
    explicitly; there is no implicit default.

## Tracker dispatch

Apply the standard `issues:` switch from `skills/lib/issue.md`. Jira
aborts with the shared message.

## Required repo-config

This command **requires** a `github-project:` block in
`.claude/rules/repo-config.md`. If the block is absent, abort with
the "No `github-project:` block in repo-config" error from the
catalogue in `skills/lib/issue.md`. This is an abort, not a
warning-and-skip — without the project metadata there is no field to
set.

## Execution (GitHub backend)

1. **Look up the issue node ID and current project item** using the
   node-ID lookup template from `skills/lib/issue.md`. Trim the query
   to `id` and the `projectItems` block.

2. **Resolve the project-item ID** per the "Project-item lookup"
   section in `skills/lib/issue.md`. If the issue is not yet on the
   configured board, call `addProjectV2ItemById` (template in the lib)
   to add it and capture the returned `item.id`.

3. **Set the importance field** via the
   `updateProjectV2ItemFieldValue` number-field template from
   `skills/lib/issue.md`. Pass:
   - `projectId = github-project.project-id`
   - `itemId = <resolved item id>`
   - `fieldId = github-project.fields.importance.id`
   - `value = <the 1-9 argument>`

4. **Handle stale field IDs.** If the mutation returns a GraphQL
   error indicating the field ID is unknown to the project (the
   `updateProjectV2ItemFieldValue` "field not found" shape), surface
   the "Project field ID no longer exists on the project" error from
   the catalogue in `skills/lib/issue.md`.

5. **Issue not found**: if the node-ID lookup returns
   `repository.issue: null`, emit the "Issue not found" error from
   the catalogue and abort.

## Output

Print one confirmation line and the issue URL:

```text
Set importance on issue #<N> to <value>.
https://github.com/<owner>/<repo>/issues/<N>
```
