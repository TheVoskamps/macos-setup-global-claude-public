---
name: issue-create
description: Create a new issue in this repo end-to-end (title, body, type, importance, status, parent, assignees, labels) in a single invocation.
---

Create a new issue in the current repo with all metadata set in one
shot: title, body, issue type, parent link, importance, status,
assignees, and labels. The command runs the full GraphQL chain so the
issue is fully configured before the URL is printed.

See `skills/lib/issue.md` for the shared GraphQL templates,
default-resolution order, name -> ID lookup rules, tracker dispatch,
and error wording. This file documents only what is specific to
`/issue-create`.

## Invocation

```
/issue-create --title "..." --body-file PATH
              [--type T] [--labels a,b,c] [--assignee u1,u2]
              [--parent N] [--importance N] [--status S]
```

- `--title` (required): issue title.
- `--body-file` (required): path to a file whose contents are used as
  the issue body verbatim. Use a file rather than `--body "..."` so
  long bodies and Markdown survive the CLI unchanged.
- `--type` (optional): issue type name (case-insensitive match against
  `issue-types:` in the repo's `github-project:` block). Default
  resolves via the order in `skills/lib/issue.md` ("Default-resolution
  order"): CLI flag, then `issue-types.default` in the repo's
  `github-project:` block, then built-in default `Feature`.
- `--labels` (optional): comma-separated label names. Passed straight
  through to `gh issue create --label`. Default: none.
- `--assignee` (optional): comma-separated GitHub usernames. Default
  resolves to the authenticated GitHub user
  (`gh api user --jq '.login'`).
- `--parent` (optional): parent issue number. When set, the new issue
  is linked as a sub-issue of the given parent via the `addSubIssue`
  template from `skills/lib/issue.md`. Default: none.
- `--importance` (optional): number between 1 and 5. Default resolves
  via the standard order ending in built-in default `3`.
- `--status` (optional): status option name (case-insensitive). Default
  resolves via the standard order ending in built-in default `Todo`.

Build the `gh issue create` invocation only from flags the user
actually passed or that resolved to a concrete value. Do not pass
empty arguments (`--label ""`, `--assignee ""`); skip the flag.

## Tracker dispatch

Apply the standard `issues:` switch from `skills/lib/issue.md`
("Tracker dispatch"). Jira aborts with the shared message.

## Execution chain (GitHub backend)

Run these steps in order; each step takes the output of the previous
step as input. If any step fails, stop and report what completed and
what didn't — do not roll back successful steps.

1. **Resolve defaults.** Apply the default-resolution order from
   `skills/lib/issue.md` to `--type`, `--importance`, `--status`,
   `--assignee`, `--labels`, and `--parent`. If `github-project:` is
   absent in repo-config, `--type` and `--assignee` still resolve via
   built-in defaults, but `--importance` and `--status` (whether
   explicit or defaulted) warn-and-skip per "Graceful degradation".

2. **Create the issue.**

   ```bash
   gh issue create \
     --title "<title>" \
     --body-file "<path>" \
     [--label "<labels>"] \
     [--assignee "<assignees>"]
   ```

   `gh issue create` prints the new issue URL on stdout. Capture it.
   Extract the issue number from the URL tail.

3. **Look up the issue node ID** using the node-ID-lookup template
   from `skills/lib/issue.md`. Trim the query to just `id` and the
   `projectItems` block (the rest of the template's fields aren't
   needed here).

4. **Look up the project-item ID** per the "Project-item lookup"
   section in `skills/lib/issue.md`. If `github-project:` is present
   and the issue is not yet on the configured board, call
   `addProjectV2ItemById` (template in the lib) to add it and capture
   the returned `item.id`.

5. **Set the issue type** via the `updateIssueIssueType` template,
   using the resolved type name -> ID lookup. Skip if there is no
   `github-project:` block (no `issue-types:` map to look up against).

6. **Link to parent**, if `--parent` was passed. Look up the parent's
   node ID (re-use the node-ID lookup template, trimmed to `id`), then
   call the `addSubIssue` template with `issueId: <parent-id>` and
   `subIssueId: <new-issue-id>`.

7. **Set importance**, if the `github-project:` block is present. Use
   the `updateProjectV2ItemFieldValue` number-field template with
   `fieldId = github-project.fields.importance.id` and the resolved
   number. If the block is missing, emit the warning from "Graceful
   degradation" in `skills/lib/issue.md` and skip.

8. **Set status**, if the `github-project:` block is present. Resolve
   the status name to an option ID via the case-insensitive lookup
   rules in `skills/lib/issue.md` ("Name -> ID lookup rules"), then
   call the `updateProjectV2ItemFieldValue` single-select-field
   template with that `optionId`. If the block is missing, warn and
   skip as in step 7.

## Output

Print one human-readable confirmation summarizing what was set, then
the new issue URL on its own line. Echo back the canonical
capitalization for type and status (per "Name -> ID lookup rules" in
`skills/lib/issue.md`), not whatever casing the user typed.

Example:

```
Created issue #1042 "Add /issue:create skill"
  type:       Feature
  importance: 3
  status:     Todo
  assignee:   edwinvoskamp
  parent:     #18

https://github.com/<owner>/<repo>/issues/1042
```

Omit lines for fields that were skipped (e.g. no `--parent`,
`github-project:` absent). When a step was warning-skipped, print the
warning line on its own (per the catalogue in `skills/lib/issue.md`)
before the URL.

## Migration note

This skill replaces the legacy `skills/issue-add/SKILL.md`. That file
now contains a one-line pointer to this skill for muscle memory.
