---
name: issue-create
description: Create a new issue in this repo end-to-end (title, body, type, importance, size, status, parent, assignees, labels) in a single invocation.
---

Create a new issue in the current repo with all metadata set in one
shot: title, body, issue type, parent link, importance, size, status,
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
              [--parent N]
              [--importance V] [--size V] [--status S]
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
- `--importance` (optional): a single token whose parse rules depend
  on `fields.importance.kind:` in the repo's `github-project:` block.
  Per-kind parse rules (same as the "Set-slot dispatcher" in
  `skills/lib/issue.md`):
  - **`kind: number`** — base-10 integer in
    `[fields.importance.min, fields.importance.max]`.
  - **`kind: single-select`** — option name from
    `fields.importance.options`, matched case-insensitively (canonical
    capitalization from the option map).
  - **`kind: label`** — option name from `fields.importance.options`
    (flat list), matched case-insensitively.
  - **`kind: skip` or slot absent** — warn-and-skip the flag (per
    "Graceful degradation" in `skills/lib/issue.md`). The value is
    not parsed or validated.

  Default resolves via the order in `skills/lib/issue.md`
  ("Default-resolution order"): CLI flag, then
  `fields.importance.default` in the repo's `github-project:` block.
  There is no built-in default — if neither is set, the slot is
  skipped.
- `--size` (optional): a single token whose parse rules depend on
  `fields.size.kind:`. Same kind dispatch as `--importance`:
  - **`kind: number`** — base-10 integer in
    `[fields.size.min, fields.size.max]`.
  - **`kind: single-select`** — option name from `fields.size.options`,
    matched case-insensitively (canonical capitalization from the
    option map).
  - **`kind: label`** — option name from `fields.size.options` (flat
    list), matched case-insensitively.
  - **`kind: skip` or slot absent** — warn-and-skip the flag.

  Default resolves via CLI flag, then `fields.size.default`. No
  built-in default; an unset slot is skipped.
- `--status` (optional): a single token whose parse rules depend on
  `fields.status.kind:`. Same kind dispatch as `--importance` and
  `--size`. Default resolves via CLI flag, then
  `fields.status.default`. No built-in default; an unset slot is
  skipped.

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
   `skills/lib/issue.md` to `--type`, `--importance`, `--size`,
   `--status`, `--assignee`, `--labels`, and `--parent`. The slot
   flags (`--importance`, `--size`, `--status`) resolve via CLI flag
   then `fields.<slot>.default` from repo-config — there is no
   built-in default; an unset slot is skipped. If `github-project:`
   is absent in repo-config, `--type` and `--assignee` still resolve
   via built-in defaults, but the slot flags (whether explicit or
   defaulted) warn-and-skip per "Graceful degradation". Likewise, a
   slot whose `kind:` is `skip`, or which is absent from `fields:`
   entirely, warns-and-skips its flag.

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

7. **Set importance**, if `--importance` resolved to a concrete value.
   Dispatch on `github-project.fields.importance.kind:` and follow the
   matching write path from the "Set-slot dispatcher" routine in
   `skills/lib/issue.md`:
   - **`kind: number`** — validate the parsed integer against
     `[min, max]`, then call the
     `updateProjectV2ItemFieldValue` number-field template with
     `fieldId = fields.importance.id`.
   - **`kind: single-select`** — resolve the option name to an
     option ID via the case-insensitive lookup rules
     ("Name -> ID lookup rules"), then call the
     `updateProjectV2ItemFieldValue` single-select-field template
     with `fieldId = fields.importance.id` and that `optionId`.
   - **`kind: label`** — resolve the option name against
     `fields.importance.options` (flat list, case-insensitive), then
     follow the "Label-namespace update" recipe with
     `<namespace> = fields.importance.namespace` and
     `<requested> = <canonical>`. This is a `gh issue edit`
     invocation, not GraphQL.
   - **`kind: skip` or slot absent** — emit the slot-skipped warning
     from "Graceful degradation" in `skills/lib/issue.md` and skip.

   If the `github-project:` block is missing entirely, emit the same
   warning and skip — there is no slot configuration to dispatch on.

8. **Set size**, if `--size` resolved to a concrete value. Same
   dispatch shape as step 7, against
   `github-project.fields.size.kind:`:
   - **`kind: number`** — validate against `[min, max]`, then call
     the `updateProjectV2ItemFieldValue` number-field template with
     `fieldId = fields.size.id`.
   - **`kind: single-select`** — resolve the option name to an
     option ID, then call the `updateProjectV2ItemFieldValue`
     single-select-field template with `fieldId = fields.size.id` and
     that `optionId`.
   - **`kind: label`** — resolve the option name against
     `fields.size.options`, then follow the "Label-namespace update"
     recipe with `<namespace> = fields.size.namespace`.
   - **`kind: skip` or slot absent** — emit the slot-skipped warning
     and skip.

   If the `github-project:` block is missing entirely, warn and skip
   as above.

9. **Set status**, if `--status` resolved to a concrete value. Same
   dispatch shape as steps 7 and 8, against
   `github-project.fields.status.kind:`. Most repos configure `status`
   as `kind: single-select`, in which case this step resolves the
   status name to an option ID via the case-insensitive lookup rules
   ("Name -> ID lookup rules") and calls the
   `updateProjectV2ItemFieldValue` single-select-field template with
   `fieldId = fields.status.id` and that `optionId`. The other three
   kinds (`number`, `label`, `skip`/absent) follow the same per-kind
   write paths as in step 7.

   If the `github-project:` block is missing entirely, warn and skip
   as above.

## Output

Print one human-readable confirmation summarizing what was set, then
the new issue URL on its own line. Echo back the canonical
capitalization for type and for any single-select / label slot value
(per "Name -> ID lookup rules" in `skills/lib/issue.md`), not whatever
casing the user typed. `kind: number` slots echo the integer as-is.

Example (with this repo's typical `single-select` importance, size,
and status):

```
Created issue #1042 "Add /issue-create skill"
  type:       Feature
  importance: P0
  size:       M
  status:     Backlog
  assignee:   edwinvoskamp
  parent:     #18

https://github.com/<owner>/<repo>/issues/1042
```

Omit lines for fields that were skipped (e.g. no `--parent`,
`github-project:` absent, or a slot whose `kind:` is `skip` /
absent). When a step was warning-skipped, print the warning line on
its own (per the catalogue in `skills/lib/issue.md`) before the URL.

## Migration note

This skill replaces the legacy `skills/issue-add/SKILL.md`. That file
now contains a one-line pointer to this skill for muscle memory.
