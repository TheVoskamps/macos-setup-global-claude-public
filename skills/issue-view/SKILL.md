---
name: issue-view
description: Dump a single issue with body, all project fields, and parent/sub-issues/blockedBy/blocking relationships in one shot.
---

Print everything about a single issue in one pass — title, body,
labels, assignees, issue type, importance, status, parent, sub-issues,
blockedBy, and blocking — without requiring follow-up commands.

See `skills/lib/issue.md` for the shared GraphQL templates, tracker
dispatch, error wording, and graceful-degradation rules. This file
documents only what is specific to `/issue-view`.

## Invocation

```
/issue-view <issue-number>
```

A single positional argument: the issue number in the current repo.
No flags.

## Tracker dispatch

Apply the standard `issues:` switch from `skills/lib/issue.md`. Jira
aborts with the shared message.

## Execution (GitHub backend)

1. **Fetch labels and assignees** via `gh issue view`:

   ```bash
   gh issue view <N> --json number,title,body,url,labels,assignees,state
   ```

   These fields are convenient to read via `gh` and avoid a second
   GraphQL round-trip.

2. **Fetch relationships and project fields** via the node-ID lookup
   template from `skills/lib/issue.md` ("Node-ID lookup by issue
   number"). Use the template as-shown — `/issue-view` is the canonical
   caller, so it consumes the full shape (issue type, parent,
   subIssues, blockedBy, blocking, issueDependenciesSummary, and
   projectItems with fieldValues).

3. **Resolve project field values.** Scan `projectItems.nodes` for the
   one whose `project.id` matches `github-project.project-id`. From
   that item's `fieldValues`:
   - The `ProjectV2ItemFieldNumberValue` whose field id matches
     `github-project.fields.importance.id` -> importance number.
   - The `ProjectV2ItemFieldSingleSelectValue` whose field id matches
     `github-project.fields.status.id` -> status name (use the
     value's `name`, which already matches the option label).

   If `github-project:` is missing from repo-config, omit the project
   fields silently per "Graceful degradation" — do not warn; reads
   degrade quietly.

   If the configured project is present but the issue has no item on
   it, print the project-fields section with each value as `(not on
   project board)` rather than failing.

4. **Issue not found**: if the node-ID lookup returns
   `repository.issue: null`, emit the "Issue not found" error from
   the catalogue in `skills/lib/issue.md` and abort.

## Output

Print a single block in this order. Sections with no content (no
labels, no assignees, no parent, empty sub-issues, etc.) are still
printed with a `(none)` placeholder so the shape is predictable for
the reader — except project fields when there is no `github-project:`
block (those are omitted entirely).

```
#<N> <title>                                       (<state>)
<url>

Labels:     <comma-separated names>
Assignees:  <comma-separated logins>
Type:       <issue-type name>
Importance: <number>
Status:     <option name>

Parent:     #<N> <title>

Sub-issues:
  - #<N> <title>
  - #<N> <title>

Blocked by:
  - #<N> <title>
  - #<N> <title>

Blocking:
  - #<N> <title>
  - #<N> <title>

Body:
<body verbatim>
```

When a section has no entries, replace its body with a single
`(none)` line — for the inline fields (`Labels:` through `Status:`
and `Parent:`), that means the value column reads `(none)`; for the
three list sections (`Sub-issues:`, `Blocked by:`, `Blocking:`),
that means the section header is followed by one `(none)` line at
the bullet indent instead of any `- #<N>` lines.

The body is printed verbatim, including its own Markdown. Do not
re-wrap or re-format it.

Parent is a single value (an issue can only have one parent). The
three other relationship sections are lists. Render
`subIssues`/`blockedBy`/`blocking` from the GraphQL `nodes` arrays in
their returned order; do not re-sort.
