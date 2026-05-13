# `/issue:*` shared reference (`skills/lib/issue.md`)

This file is the single source of truth for the `/issue:*` command
namespace. It is **reference prose**, not an executable script: Claude
reads it when running any `/issue:*` command and follows the patterns
documented here. Individual command files (`/issue:create`,
`/issue:view`, `/issue:set-status`, `/issue:set-importance`,
`/issue:set-parent`, `/issue:set-child`, `/issue:set-blocked-by`,
`/issue:set-blocks`, `/issue:sub-list`, `/issue:close`,
`/issue:comment`, etc.) reference this doc rather than duplicating
GraphQL templates or default-resolution logic inline.

`/issue:address` is **not** part of this namespace and does not read
this file — it is the higher-level multi-issue orchestrator and
predates `skills/lib/issue.md`.

## Repo-config parsing

Every `/issue:*` command runs from a repo working tree and starts by
reading `<repo-root>/.claude/rules/repo-config.md`. Find the repo root
with `git rev-parse --show-toplevel`; do not assume the user's cwd is
the root.

If the file is missing, abort with:

> This repo has no `.claude/rules/repo-config.md`. /issue:* commands
> require it. Run `/repo:config` to create one interactively.

The file has two parts: a YAML front-matter block (six keys, defined
by `/repo:config`) and a prose body. The new commands read **two
sections**:

1. **Front-matter** — same six keys `/issue:address` reads:
   `source-control`, `issues`, `issue-link-prefix`,
   `default-issue-source-branch`, `default-pr-target-branch`,
   `issue-branch-naming-prefix`. Used for tracker dispatch and
   issue-link formatting.
2. **`github-project:` block in the body** — optional. Parsed as YAML.
   When present, supplies the project ID, field IDs, status option
   IDs, and issue type IDs for the current repo. Schema:

   ```yaml
   github-project:
     project-id: PVT_kwDO...   # ProjectV2 node ID
     fields:
       importance:
         id: PVTF_lADO...      # number-field ID
         type: number
         default: 3
       status:
         id: PVTSSF_lADO...    # single-select field ID
         type: single-select
         default: Todo
         options:
           Backlog:     <option-id>
           Todo:        <option-id>
           In Progress: <option-id>
           In review:   <option-id>
           Done:        <option-id>
     issue-types:
       default: Feature
       Bug:     IT_kwDO...
       Feature: IT_kwDO...
       Goal:    IT_kwDO...
       Problem: IT_kwDO...
   ```

   The IDs shown are illustrative. Per-repo IDs are populated by
   `/repo:config` (which discovers them via `gh project list`,
   `gh project field-list`, and a GraphQL query for issue types) and
   are stable for the life of the project board.

### Locating the `github-project:` block

Scan the body (everything after the closing front-matter `---`) for a
line that starts with `github-project:` at column 0. The block runs
until the next column-0 non-blank line (a new top-level key) or EOF.
Parse the indented YAML beneath it.

### Graceful degradation when the block is missing

Repos without a Project V2 board omit the `github-project:` block
entirely. In that case:

- Commands that only touch the issue itself (`/issue:create` without
  `--type/--importance/--status`, `/issue:update`, `/issue:close`,
  `/issue:comment`, `/issue:set-parent`, `/issue:set-child`,
  `/issue:set-blocked-by`, `/issue:set-blocks`, `/issue:sub-list`,
  `/issue:view`) work normally — they don't need project metadata.
- Commands or flags that **require** project metadata
  (`--type`, `--importance`, `--status`, `/issue:set-importance`,
  `/issue:set-status`) emit a one-line warning and skip that step
  rather than aborting the whole run. Example:

  > `warning: no github-project: block in repo-config.md;`
  > `skipping --status. Run /repo:config to add it.`

- `/issue:view` prints whatever project fields it can read; if there's
  no project, the project-fields section is omitted.

## Tracker dispatch

Every command opens with the same `issues:` switch as `/issue:address`:

- `issues == GitHub`: continue with the GitHub code path documented
  below.
- `issues == Jira`: abort with:

  > `issues: Jira` selected, but the Jira backend is not implemented.
  > See #103.

  Mirror `/issue:address`'s abort message verbatim so the user sees a
  consistent error across the namespace.

## Default-resolution order

For every flag with a default, resolve in this exact order — first
hit wins:

1. **CLI flag** explicitly passed on the command line.
2. **Repo-config default** in the relevant section of the
   `github-project:` block (`fields.importance.default`,
   `fields.status.default`, `issue-types.default`).
3. **Built-in default** (the values below).

Built-in defaults:

- `--type`       — `Feature`
- `--importance` — `3`
- `--status`     — `Todo`
- `--assignee`   — the authenticated GitHub user
  (`gh api user --jq .login`)
- `--labels`     — (none)
- `--parent`     — (none)

A repo-config-level default only applies when its containing block
exists. If `github-project:` is absent, the built-in default still
applies for `--type` and `--assignee` and `--labels`, but
`--importance` and `--status` cannot be set at all (warning-and-skip
per "Graceful degradation" above).

## Name -> ID lookup rules

CLI flags accept **human-readable names**, never raw node IDs. Names
are translated to IDs by looking them up in the `github-project:`
block.

- **Case-insensitive match.** `todo`, `Todo`, and `TODO` all resolve
  to the `Todo` option.
- **Canonical capitalization from the map.** When echoing the chosen
  value back to the user ("set status to Todo"), use the spelling
  exactly as it appears in the option map key, not whatever casing
  the user typed.
- **Whitespace is significant.** `In Progress` and `In  Progress`
  (two spaces) are different keys; project boards routinely have
  multi-word status options. YAML parsers typically collapse or
  drop internal multi-spacing in unquoted keys, so if an option
  name genuinely contains consecutive spaces, quote the key
  (e.g. `"In  Progress": <option-id>`) to preserve them.
- **No fuzzy matching.** If the name doesn't match an option in the
  map (after case-folding), emit the "not in options" error from the
  catalogue below. Don't guess.

The same rules apply to issue type names against `issue-types:` and
to any other name-to-ID lookups added later.

## "One edge, two sides" pattern

Several GitHub-issue relationships are **single edges in the data
model** but are exposed by the `/issue:*` namespace as **two verbs**
— one verb per direction — because users think about them from
either end. The underlying API still has only one mutation per edge;
the two verbs differ only in argument order.

Verb pairs that share an edge:

- **`set-blocked-by` / `set-blocks`** — same blocked-by edge.
  - `set-blocked-by N B` calls `addBlockedBy(issueId: N, blockingIssueId: B)`
    ("issue N is blocked by issue B").
  - `set-blocks N B` calls `addBlockedBy(issueId: B, blockingIssueId: N)`
    ("issue N blocks issue B" — same edge, written from the other side).
  - `unset-blocked-by` / `unset-blocks` mirror this with
    `removeBlockedBy`.
- **`set-parent` / `set-child`** — same sub-issue edge.
  - `set-parent C P` calls `addSubIssue(issueId: P, subIssueId: C)`
    ("the parent of C is P").
  - `set-child P C` calls `addSubIssue(issueId: P, subIssueId: C)`
    ("a child of P is C").
  - `unset-parent` / `unset-child` mirror this with `removeSubIssue`.

The namespace exposes both directions even though the underlying API
only offers one mutation per edge (`addBlockedBy` only, no
`addBlocking`; `addSubIssue` only, no `addParent`). Reading is
symmetric in the schema: `Issue.blockedBy` and `Issue.blocking` are
the same edge read from opposite sides, and `Issue.parent` /
`Issue.subIssues` are the same.

When implementing a new verb in this namespace, decide which side of
an existing edge it lives on **before** writing a new mutation
template — odds are the mutation already exists in this doc and you
just need to flip the arguments.

## GraphQL templates

All templates below are GitHub GraphQL v4 (`gh api graphql`). The
field names were confirmed by introspection against the live schema.
To re-verify any input type, run a query of this shape, substituting
the input type name in the `__type(name: "...")` argument:

```bash
gh api graphql -f query='
query {
  __type(name: "AddBlockedByInput") {
    inputFields { name type { name kind ofType { name } } }
  }
}'
```

The input types this doc relies on, all verified via the query above:
`AddBlockedByInput`, `RemoveBlockedByInput`, `AddSubIssueInput`,
`RemoveSubIssueInput`, `UpdateProjectV2ItemFieldValueInput`,
`UpdateIssueIssueTypeInput`.

Use the templates below verbatim.

Variable substitutions use `<...>` for the call site to fill in.
Where the template takes runtime arguments, prefer
`gh api graphql -f query='...' -F name=value` to interpolating
shell-escaped strings. Use `-f` (string) for `ID!` arguments; `-F`
coerces to int/bool when the value parses as one, which can mangle
node IDs — reserve `-F` for numeric or boolean arguments only.

### Node-ID lookup by issue number

```graphql
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $number) {
      id
      title
      url
      issueType { id name }
      parent { number title }
      subIssues(first: 50)  { nodes { number title url } }
      blockedBy(first: 50)  { nodes { number title url } }
      blocking(first: 50)   { nodes { number title url } }
      issueDependenciesSummary {
        blockedBy blocking totalBlockedBy totalBlocking
      }
      projectItems(first: 10) {
        nodes {
          id
          project { id number title }
          fieldValues(first: 20) {
            nodes {
              __typename
              ... on ProjectV2ItemFieldNumberValue {
                field { ... on ProjectV2FieldCommon { id name } }
                number
              }
              ... on ProjectV2ItemFieldSingleSelectValue {
                field { ... on ProjectV2FieldCommon { id name } }
                name
                optionId
              }
            }
          }
        }
      }
    }
  }
}
```

Most commands need only a subset of those fields. Trim the query to
what the caller actually uses; the shape above is what `/issue:view`
returns in one shot.

### Project-item lookup

The project-item ID is **different** from the issue node ID. Field
mutations target the project item, not the issue. To find it for a
given issue, scan `Issue.projectItems(first: N)` (above) and pick the
node whose `project.id` matches the configured `project-id`. Cache
the resulting `itemId` for the lifetime of the command — it doesn't
change.

If the issue is not yet on the project board, add it first:

```graphql
mutation($projectId: ID!, $contentId: ID!) {
  addProjectV2ItemById(input: {
    projectId: $projectId
    contentId: $contentId
  }) {
    item { id }
  }
}
```

`/issue:create` calls this automatically when `github-project:` is
configured. Other commands either fail with the "not on project
board" error (read-only paths) or call it on demand (write paths
like `/issue:set-status`).

### `addSubIssue` / `removeSubIssue`

Parent/child edge. `issueId` is the parent; `subIssueId` is the
child.

```graphql
mutation($parentId: ID!, $childId: ID!) {
  addSubIssue(input: { issueId: $parentId, subIssueId: $childId }) {
    issue    { id number title }
    subIssue { id number title }
  }
}
```

```graphql
mutation($parentId: ID!, $childId: ID!) {
  removeSubIssue(input: { issueId: $parentId, subIssueId: $childId }) {
    issue    { id number title }
    subIssue { id number title }
  }
}
```

The `AddSubIssueInput` type also accepts a `subIssueUrl` (instead of
`subIssueId`) and a `replaceParent: Boolean` flag — leave those off
for now; the namespace standardizes on the ID-based form.

### `addBlockedBy` / `removeBlockedBy`

Blocked-by edge. Introspection confirms the input fields are
`issueId` (the issue that **is blocked**) and `blockingIssueId` (the
**blocker**). There is no separate `addBlocking` mutation — write
"X blocks Y" as "Y is blocked by X" by swapping the arguments.

```graphql
mutation($issueId: ID!, $blockingIssueId: ID!) {
  addBlockedBy(input: {
    issueId: $issueId
    blockingIssueId: $blockingIssueId
  }) {
    issue         { id number title }
    blockingIssue { id number title }
  }
}
```

```graphql
mutation($issueId: ID!, $blockingIssueId: ID!) {
  removeBlockedBy(input: {
    issueId: $issueId
    blockingIssueId: $blockingIssueId
  }) {
    issue         { id number title }
    blockingIssue { id number title }
  }
}
```

Call-site mapping:

- `set-blocked-by N B`
  → `issueId: <node-id-of-N>`, `blockingIssueId: <node-id-of-B>`
- `set-blocks N B`
  → `issueId: <node-id-of-B>`, `blockingIssueId: <node-id-of-N>`

### `updateProjectV2ItemFieldValue` — number field (importance)

```graphql
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: Float!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId
    itemId:    $itemId
    fieldId:   $fieldId
    value:     { number: $value }
  }) {
    projectV2Item { id }
  }
}
```

`projectId` and `fieldId` come from the `github-project:` block.
`itemId` comes from the project-item lookup. `value` is the resolved
importance (CLI flag, repo-config default, or 3).

### `updateProjectV2ItemFieldValue` — single-select field (status)

```graphql
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId
    itemId:    $itemId
    fieldId:   $fieldId
    value:     { singleSelectOptionId: $optionId }
  }) {
    projectV2Item { id }
  }
}
```

`optionId` is resolved by case-insensitive lookup of the chosen
status name in `fields.status.options`.

Note: the `ProjectV2FieldValue` input type uses `singleSelectOptionId`
(not `optionId`). Don't confuse this with the field-level `optionId`
returned by reads of `ProjectV2ItemFieldSingleSelectValue`.

### `updateIssueIssueType` (set issue type)

```graphql
mutation($issueId: ID!, $issueTypeId: ID!) {
  updateIssueIssueType(input: {
    issueId: $issueId
    issueTypeId: $issueTypeId
  }) {
    issue { id number issueType { id name } }
  }
}
```

`issueTypeId` is resolved by case-insensitive lookup of the chosen
type name (e.g. `Bug`, `Feature`) in the `issue-types:` map. To
**clear** the issue type, pass `issueTypeId: null` (the input field
is nullable).

## Error message catalogue

Use these exact wordings so the namespace presents consistent errors.
Wrap variable parts in backticks.

- **Issue not found**

  > issue `#<N>` not found in `<owner>/<repo>`

  Triggered when the node-ID lookup returns `repository.issue: null`.
  Includes the repo so the user can spot a wrong-repo invocation.

- **Status name not in repo's option map**

  > status `<name>` not in repo's
  > `github-project.fields.status.options`. Known options:
  > `<comma-separated canonical names>`

  The comma-separated list is the canonical names from the map keys,
  in the order they appear in the YAML.

- **No `github-project:` block in repo-config**

  > no `github-project:` block in `repo-config.md`; run `/repo:config` to add it

  Emitted as an **abort** when the command **requires** project
  metadata (e.g. `/issue:set-status` with no flags can't proceed) and
  as a **warning-and-skip** when only a subset of flags need it (see
  "Graceful degradation" above).

- **Jira backend not implemented**

  > `issues: Jira` selected, but the Jira backend is not implemented.
  > See #103.

  Mirrors `/issue:address`'s abort word-for-word so users see one
  consistent error across the namespace.

- **Issue not on the configured project board** (read paths only)

  > issue `#<N>` is not on project `<project-title>`
  > (`<project-id>`); add it first or run a write command which
  > adds it on demand

  Avoid this for write paths; those should add the item automatically
  via `addProjectV2ItemById`.

- **Issue-type name not in repo's issue-types map**

  > issue type `<name>` not in repo's `github-project.issue-types`.
  > Known types: `<comma-separated canonical names>`

When a command emits multiple warnings in one run (e.g. `--status`
and `--importance` both skipped because `github-project:` is missing),
print them on separate lines, in the order the flags appeared on the
CLI.

## Conventions for command files

When writing a new `/issue:*` command's `.md`:

- Open with one or two sentences describing the command's intent.
- Link to this file: "See `skills/lib/issue.md` for shared GraphQL
  templates, default resolution, and error wording."
- Document only what's specific to that command: argument shape,
  which templates from this file it uses, and any per-command
  edge cases.
- Do **not** copy GraphQL templates inline — reference them by name
  ("uses the `addSubIssue` template from `skills/lib/issue.md`").
- Do **not** restate the default-resolution order — reference it.
- Do **not** restate the tracker-dispatch open — reference it.
