---
name: repo-config
description: Interactively create or update `.claude/rules/repo-config.md` by interviewing the user about VCS, issue tracker, and (for GitHub repos) the associated Project V2 board.
---

You are running the `/repo-config` skill. Your job is to create or
update the **target repo's** `.claude/rules/repo-config.md` by
interviewing the user. This file is read by `/issue-address` and the
`issue-developer`, `issue-fixer`, `doc-updater`, and `pr-reviewer`
subagents at the start of every run, so it must be present and well
formed before any of those flows will work.

Follow the steps below in order. Do not write the file until the
user has explicitly approved the proposed content.

---

## Step 1: Pre-flight

Verify you are inside a git working tree by running:

```bash
git rev-parse --show-toplevel
```

If the command fails (non-zero exit, or stderr indicates "not a git
repository"), abort with a clear message:

> `/repo-config` must be run from inside a git repository. The current
> directory is not a git working tree.

Do not continue past this step on failure.

Treat the path printed by `git rev-parse --show-toplevel` as the
**repo root** for the rest of the skill — the skill writes
`<repo-root>/.claude/rules/repo-config.md` regardless of which
subdirectory of the worktree the user invoked the command from. Do
**not** string-compare the printed path against the user's current
working directory: `git rev-parse --show-toplevel` returns a real
path, while the user's cwd may traverse symlinks (for example, on
macOS `/tmp` resolves to `/private/tmp`, and project trees frequently
sit under symlinked workspace directories). A naive equality check
would mis-flag a legitimate repo as "not a repo root".

## Step 2: Detect existing config

Check whether `.claude/rules/repo-config.md` already exists in the
target repo (relative to the repo root from Step 1).

- **If it exists**: read the file and parse the YAML front-matter
  (the block delimited by `---` at the top) into the six known keys
  listed in Step 3. Any value found becomes the **recommended
  default** for that field's question. Preserve the body of the
  file (everything after the closing `---`) verbatim — Steps 5 and
  5b are the only places that may rewrite parts of the file, and
  each rewrites only its own region.
- **If it does not exist**: use these built-in defaults:
  - `source-control`: `GitHub`
  - `issues`: `GitHub`
  - `issue-link-prefix`: `#`
  - `default-issue-source-branch`: `main`
  - `default-pr-target-branch`: `main`
  - `issue-branch-naming-prefix`: `none`

If the existing file is malformed (missing front-matter delimiters,
unparseable YAML, or contains keys you don't recognize), surface
the problem to the user and ask whether to fall back to built-in
defaults or stop. Do not attempt to silently "fix" the file.

Also, before Step 3, gather the local branch list with
`git branch --format='%(refname:short)'` so you can offer real
branches as options for the two branch fields.

### Detect existing `github-project:` block

After parsing the front-matter, scan the body (everything after the
closing front-matter `---`) for a line that starts with
`github-project:` at column 0. The block runs until the next column-0
non-blank line (a new top-level body key, a Markdown heading like
`# ...` or `## ...`, etc.) or EOF. This matches the scan rule in
`skills/lib/issue.md` so the wizard and the consumers agree on
boundaries.

If a block is found:

- Capture its **exact literal bytes** — opening `github-project:`
  line through the last line of the indented block, inclusive, with
  original line endings and trailing whitespace. Step 5b uses this
  verbatim as `old_string` if the block is changing.
- Also capture any **immediately preceding comment lines** that
  document why the block is present or absent (lines starting with
  `<!--` ... `-->` or `#` that sit directly above the block with no
  blank line in between). On a rewrite, treat these as part of the
  block's region so they don't get orphaned.
- Parse the indented YAML beneath the `github-project:` key into the
  schema shown in `skills/lib/issue.md` (project-id, fields,
  issue-types). Values found here become the **recommended defaults**
  for the corresponding github-project questions in Step 3b.

If a block is **not** found, also look for a "skip marker" — an HTML
comment of the exact form:

```text
<!-- github-project: intentionally omitted; <reason>. -->
```

If present, treat it as "the user previously chose to skip"; Step 3b
will recommend `Skip` and surface the prior reason. Capture its
literal bytes too.

If neither a block nor a skip marker is present, the github-project
state is "absent" — Step 3b will offer to populate it.

Malformed `github-project:` YAML (unparseable, unknown keys, missing
required sub-keys) is surfaced the same way as malformed front-matter:
tell the user and ask whether to discard the block and start over from
auto-discovery, or stop. Do not silently rewrite a broken block.

## Step 2.5: Confirm intent to edit (existing file only)

This step runs **only if the file existed** in Step 2. If the file
did not exist, skip directly to Step 3.

Many invocations of `/repo-config` are "just check what's
configured", not "I want to change something". Walking through the
six interview questions only to land on "don't change anything" is
friction. Gate the interview behind a single yes/no so the common
inspection case exits immediately.

1. Display the **full current contents** of
   `.claude/rules/repo-config.md` to the user — front-matter and
   body, byte-for-byte as read from disk. Do not paraphrase, summarize,
   or show only the front-matter; the user is inspecting the real
   file.
2. Ask via `AskUserQuestion`: "Do you want to make changes?" with
   options `Yes` and `No`.
3. **On `No`**: end the skill cleanly. Report that the file was
   left unchanged at `<repo-root>/.claude/rules/repo-config.md`.
   Do **not** enter the interview. Do **not** write or edit
   anything. Skip Steps 3 through 6.
4. **On `Yes`**: continue into Step 3 with current values as
   recommended defaults (the existing behavior).

Do not show a diff at this stage — Step 4 still owns the
post-interview diff, and there is nothing to diff against yet.

## Step 3: Interview

Use the `AskUserQuestion` tool to interview the user. Ask the six
fields **in the order below**. Group them into multiple
`AskUserQuestion` calls as feels natural — the tool allows 1–4
questions per call, and exact grouping is left to your judgment.

For every question:

- The **first option** must be the recommended/current value,
  with its label suffixed `(Recommended)`.
- Always include an "Other" option so the user can type a custom
  value.
- Keep option labels short; put any explanation in the question
  text.

The six fields, in order:

1. **`source-control`** — choose `GitHub` or `CodeCommit`.
   Recommend whatever the existing file had, otherwise `GitHub`.
2. **`issues`** — choose `GitHub` or `Jira`. Recommend whatever
   the existing file had, otherwise `GitHub`.
3. **`issue-link-prefix`** — the literal string concatenated with
   the issue number in commit messages and PR bodies. The recommended
   value depends on the **just-chosen** value of `issues` (field 2),
   not on what the existing file said, because users sometimes
   re-run this skill specifically to switch issue trackers and the
   old prefix is then meaningless.
   - If the user picked `GitHub` for `issues`, recommend `#`
     regardless of the existing value. (`#123` is the only sensible
     GitHub form.)
   - If the user picked `Jira` for `issues`:
     - If the existing value ends with a dash and is non-empty (e.g.
       `SET-`, `PROJ-`), recommend it — it is plausibly a Jira key.
     - Otherwise (no existing value, or an existing value like `#`
       carried over from a prior `GitHub` configuration), ignore the
       existing value and prompt the user to enter the Jira project
       key plus a trailing dash via "Other" (e.g. `SET-`, `PROJ-`).
       Do not pre-fill `#` as a recommendation in the Jira case.
4. **`default-issue-source-branch`** — branch that new issue work
   branches FROM. Offer the local branches you gathered in Step 2
   as options, plus "Other" for any branch name. Recommend the
   existing value if any, otherwise `main`.
5. **`default-pr-target-branch`** — branch that issue PRs target.
   Same option set as field 4. Recommend the existing value if
   any, otherwise default to whatever the user just chose for
   `default-issue-source-branch` (often the same).
6. **`issue-branch-naming-prefix`** — branch naming style.
   Choose one of `none`, `initials`, `name`. Recommend whatever
   the existing file had, otherwise `none`.

Do not validate that the chosen branches actually exist on the
remote; that is out of scope for this skill.

## Step 3b: GitHub Project interview (conditional)

This step runs **only when the just-chosen `issues` value is `GitHub`**.
If `issues` is `Jira` (or anything other than `GitHub`), skip this
step entirely and proceed to Step 4. Do not prompt for any
project-related values under Jira; the `github-project:` block is a
GitHub-only concept and the Jira branch will eventually get a parallel
`jira:` block.

The purpose of this step is to populate (or update, or intentionally
omit) the `github-project:` body block defined in `skills/lib/issue.md`.
The block carries project node IDs, status option IDs, and issue type
IDs so the `/issue-*` commands can translate human-readable names
into the GraphQL IDs the GitHub API requires.

### 3b.1 — Decide whether to populate

Use `AskUserQuestion` to ask the user how to handle the
`github-project:` block. The set of options and the recommended one
depend on the state captured in Step 2:

- **Block present** — offer `Keep`, `Update`, `Remove`. Recommend
  `Keep`.
- **Skip marker present (no block)** — offer `Skip again`,
  `Populate`. Recommend `Skip again`.
- **Neither block nor skip marker (absent)** — offer `Populate`,
  `Skip`. Recommend `Populate`.

Option meanings:

- **Keep**: leave the existing block (and any preceding comments)
  byte-for-byte. Set the github-project diff to "no change" and exit
  this step.
- **Update**: re-run auto-discovery (Steps 3b.2 - 3b.5) using the
  existing block's values as recommended defaults where applicable.
  Replace the block on write.
- **Remove**: delete the block on write and replace it with a skip
  marker (see 3b.6). Ask for a short free-form reason via "Other".
- **Populate**: run auto-discovery for the first time. Build the block
  from scratch.
- **Skip** / **Skip again**: do not add a block. Write (or keep) the
  skip marker with a short reason. Recommended reason for "Skip
  again" is whatever the existing marker said; for first-time "Skip",
  ask via "Other".

On `Keep` or `Skip again` with no reason change, set the github-project
diff to "no change" and proceed to Step 4. Otherwise continue with
3b.2 onward.

### 3b.2 — Pick the owner and project

Auto-discover the repo's owner from the local remote:

```bash
git remote get-url origin
```

Parse the `owner/repo` from the URL (both SSH and HTTPS forms; strip
any trailing `.git`). The owner is typically a GitHub organization but
may be a user; both work as `--owner` arguments to `gh project list`.

List accessible projects for that owner:

```bash
gh project list --owner <owner> --format json
```

Parse the JSON. The shape is `{ projects: [ { number, title, id,
... } ] }`. Each project's `id` is the ProjectV2 node ID (`PVT_...`),
which is the literal value that goes into `project-id`.

Show the user the discovered projects with their numbers and titles,
plus options:

- One option per discovered project (label: `<number>: <title>`).
- `Other` to type a project number by hand (useful when the project
  belongs to an upstream org `gh project list` can't see, or when the
  list is truncated by `--limit`).
- `Skip` to abandon the github-project block. On `Skip`, jump to
  3b.6 to record the skip marker.

Common failure modes to handle gracefully:

- `gh project list` exits non-zero or returns an empty list. Surface
  the error/empty result and offer `Other` (manual entry) or `Skip`.
- The user picks `Other` and enters a project number. Resolve its
  node ID by running `gh project view <number> --owner <owner>
  --format json` and reading `.id` (also `.title` for the summary).

If the project node ID does not start with `PVT_`, treat the response
as invalid and let the user retry or skip.

Record:

- `project-id` — the `PVT_...` node ID.
- The numeric project number and title (for the summary in Step 6;
  these are not written to the file).

### 3b.3 — Discover fields (per-slot interview)

This step runs the same generic interview once per conceptually-standard
slot. The slot list is hardcoded: `status`, `importance`, `size`. Making
the slot list user-configurable is out of scope; a repo that wants a
different slot (e.g. `priority`) hand-edits the block after the wizard
runs, per the schema in `skills/lib/issue.md`.

#### 3b.3.a — Enumerate project fields once

Before asking about any slot, enumerate the project's fields a single
time and keep the result in memory for the per-slot loop below. The
goal is one unified list of `(id, name, kind, options?)` tuples where
`kind` is one of `number` or `single-select` — the only two kinds that
correspond to project fields. Iteration, text, date, and built-in
fields (Title, Assignees, Labels, Milestone, etc.) are filtered out:
they are not surfaceable as slot backings.

Detecting which fields are number-typed is the tricky part. The
`gh project field-list` JSON returns `type == "ProjectV2Field"` for
**every** non-single-select, non-iteration field — Title, Assignees,
Labels, Milestone, Repository, Reviewers, Parent issue, Sub-issues
progress, Estimate, Start date, Target date, Importance, and any
custom text/number/date field the user has added. The `type`
discriminator alone is not enough to identify a number field. Use the
GraphQL `dataType` probe as the canonical discriminator:

```bash
gh api graphql -F number=<project-number> -F owner=<owner> -f query='
query($owner: String!, $number: Int!) {
  organization(login: $owner) {
    projectV2(number: $number) {
      fields(first: 100) {
        nodes {
          ... on ProjectV2Field             { id name dataType }
          ... on ProjectV2SingleSelectField { id name dataType
            options { id name } }
          ... on ProjectV2IterationField    { id name dataType }
        }
      }
    }
  }
}'
```

If the owner is a user (not an org), swap `organization(login:)` for
`user(login:)`. `dataType` is one of `NUMBER`, `TEXT`, `DATE`,
`SINGLE_SELECT`, `ITERATION`, `TITLE`, `ASSIGNEES`, `LABELS`,
`MILESTONE`, `REPOSITORY`, `REVIEWERS`, `LINKED_PULL_REQUESTS`,
`TRACKS`, `TRACKED_BY`.

From the response, build two lists for the per-slot loop:

- **Number fields**: every node with `dataType == "NUMBER"`. Capture
  `id` (`PVTF_...`) and `name`. No options.
- **Single-select fields**: every node with `dataType == "SINGLE_SELECT"`.
  Capture `id` (`PVTSSF_...`), `name`, and the full `options` list
  (each `{ id, name }`). The option IDs are short hex strings, not
  `PVT_*`-prefixed node IDs — that is correct for single-select option
  IDs in ProjectV2.

`gh project field-list <project-number> --owner <owner> --format json`
also works as a fallback for the name/type pass when the GraphQL probe
is unavailable, but it cannot distinguish number from text/date and
does not expose option IDs, so prefer the GraphQL form when both are
available.

#### 3b.3.b — Per-slot interview

Run the **same** four-step procedure once per slot, in this order:

1. **`status`** — strongly recommended. Default-recommendation chain
   for which kind to pick: a single-select field named `Status`
   (case-insensitive) if exactly one such field is enumerated.
2. **`importance`** — optional. Default-recommendation chain for which
   kind to pick: a number field named `Importance` or `Priority`
   (case-insensitive) if exactly one such field is enumerated;
   otherwise a single-select field with the same name.
3. **`size`** — optional. Default-recommendation chain for which kind
   to pick: a single-select or number field named `Size` or `T-Shirt`
   (case-insensitive) if exactly one such field is enumerated;
   otherwise the `label` kind with a recommended namespace of `size:`.

For every slot, the procedure is:

##### Step 1 — Show every option the user could pick

Present, in one `AskUserQuestion` call, the full set of choices for
this slot:

- One option per enumerated **number field** from 3b.3.a (label:
  `<name> (number field)`).
- One option per enumerated **single-select field**, with its option
  list shown inline so the user can see what they would be choosing
  (label: `<name> (single-select: opt1, opt2, opt3, ...)`). If the
  inline list would overflow the question UI, truncate with `, ...`
  after the first few — the user is selecting the field, not the
  option, so a partial list is enough to disambiguate.
- One option for **labels**: `As labels (with namespace prefix)` —
  independent of project fields. This kind corresponds to
  `kind: label` in the rendered block.
- One option for **skip**: `None / skip` — slot stays unconfigured
  (rendered as `kind: skip`, or omitted entirely if the user prefers;
  see Step 3 below).

Mark the recommended choice with `(Recommended)` in its label per the
chain above. For `status`, if no `Status`-named single-select field
exists, fall back to recommending the first single-select field, then
`None / skip` as a last resort — status is strongly recommended but
not enforced.

##### Step 2 — Ask the user which to use

Use the option set from Step 1 directly. There is no slot-specific
override; the user picks one of the enumerated kinds.

##### Step 3 — Follow up based on the user's pick

Dispatch on the chosen kind:

- **Number field** (`kind: number`):
  - Capture the field `id` (`PVTF_...`) from the enumeration.
  - Ask for `default` (integer or float). Recommend the existing
    block's `fields.<slot>.default` if any; otherwise no recommendation
    — the user owns the range.
  - Ask for `min` (integer or float). Recommend the existing block's
    `fields.<slot>.min` if any; otherwise no built-in default.
  - Ask for `max` (integer or float). Recommend the existing block's
    `fields.<slot>.max` if any; otherwise no built-in default.

- **Single-select field** (`kind: single-select`):
  - Capture the field `id` (`PVTSSF_...`) and the full option
    name→id map from the enumeration.
  - Ask which option should be the **default** for new issues. The
    recommendation chain is slot-aware:
    - For `status`: the existing block's `fields.status.default` (if
      it matches one of the current options case-insensitively), then
      `Backlog` (if present), then the first option in the list.
    - For other slots: the existing block's `fields.<slot>.default`
      (if it matches case-insensitively), then the first option in
      the list.
  - Always include an `Other` choice to free-type one of the
    enumerated option names.

- **Labels** (`kind: label`):
  - Ask for the **namespace prefix**. Recommend `<slot>:` (e.g.
    `size:` for the `size` slot). Free-text via `Other` for any other
    value; trailing colon is conventional but not enforced by the
    wizard.
  - Ask for the **option list** as a comma-separated string (e.g.
    `XS, S, M, L, XL`). Recommend the existing block's
    `fields.<slot>.options` joined back into a comma list if any.
    Split on commas, trim whitespace from each entry; reject empty
    entries.
  - Ask for the **default** option (must be one of the entered
    options, case-insensitive match against the list). Recommend the
    existing block's `fields.<slot>.default` if it still matches one
    of the entered options; otherwise the first entry in the list.
  - No field `id` is captured — labels are not project fields and
    the label name is its own identifier.

- **Skip** (`kind: skip`):
  - Nothing to capture beyond `kind: skip`. The slot is explicitly
    declared as unused. Verbs that target the slot warn and exit
    zero per the "Field kinds" section of `skills/lib/issue.md`.
  - For the `status` slot specifically, `Skip` is allowed but
    discouraged — surface a brief note to the user that
    `/issue-set-status` and the `--status` flag will warn-and-skip,
    then accept the user's choice without re-prompting.

##### Step 4 — Defer rendering to 3b.5

Hold the captured per-slot state in memory. Step 3b.5 assembles all
slots into the final YAML block once the loop finishes; do not write
or edit the file from inside this loop.

### 3b.4 — Discover issue types

GitHub Issue Types are an org-level (and now repo-scoped) enum. There
is no `gh issue-type` command yet; query via GraphQL:

```bash
gh api graphql -F owner=<owner> -F repo=<repo> -f query='
query($owner: String!, $repo: String!) {
  repository(owner: $owner, name: $repo) {
    issueTypes(first: 50) {
      nodes { id name isEnabled }
    }
  }
}'
```

Filter to `isEnabled: true`. Each enabled type contributes
`<Name>: <id>` to the `issue-types:` map (preserve the capitalization
GitHub returns). Skip types that are disabled.

If the query returns an empty list or the field is `null` (older repos
without issue types enabled), ask the user whether to:

- `Skip issue-types` — omit the `issue-types:` sub-block entirely.
- `Other` — manually enter `Name: IT_...` pairs.

Ask the user which type should be the **default**. Recommend, in
order: the existing block's `issue-types.default` (if still valid),
then `Feature` (if present), then the first type in the list. Include
`Other` for free-type.

### 3b.5 — Assemble the proposed block

From the captured per-slot state in 3b.3.b and the issue-types map in
3b.4, render the YAML block that will be written to the file. Use the
exact indentation and key order shown below (matching the schema in
`skills/lib/issue.md`). Every populated slot under `fields:` carries
its `kind:` discriminator (`number`, `single-select`, `label`, or
`skip`) — there is no implicit default and no backwards-compat shim
for the old `type:` shape.

The renderer is purely a function of the captured state — it never
invents defaults or substitutes built-in fallbacks for kind-specific
keys. Every key in the rendered block traces back to a value the user
either supplied directly (via "Other") or selected from an enumerated
option in 3b.3.b or 3b.4.

#### Per-kind render shapes

For each populated slot, emit one of the following shapes based on the
slot's captured `kind`:

- **`kind: number`** — emit `kind`, `id`, `default`, `min`, `max`:

  ```yaml
  <slot-name>:
    kind: number
    id: <field-id>
    default: <number>
    min: <number>
    max: <number>
  ```

- **`kind: single-select`** — emit `kind`, `id`, `default`, and the
  option name→id map:

  ```yaml
  <slot-name>:
    kind: single-select
    id: <field-id>
    default: <option-name>
    options:
      <Option Name>: <option-id>
      ...
  ```

- **`kind: label`** — emit `kind`, `namespace`, `default`, and the
  flat option list. No `id` (labels are not project fields). The
  `namespace` value is double-quoted because trailing-colon strings
  like `size:` would otherwise be interpreted as a YAML mapping key:

  ```yaml
  <slot-name>:
    kind: label
    namespace: "<namespace>"
    default: <option-name>
    options: [<opt1>, <opt2>, ...]
  ```

- **`kind: skip`** — emit `kind: skip` and nothing else:

  ```yaml
  <slot-name>:
    kind: skip
  ```

#### Full-block shape

The assembled block looks like:

```yaml
github-project:
  project-id: <project-id>
  fields:
    status:
      <per-kind shape from above>
    importance:
      <per-kind shape from above>
    size:
      <per-kind shape from above>
  issue-types:
    default: <Type Name>
    <Type Name>: <type-id>
    ...
```

Slot order under `fields:` is fixed: `status`, then `importance`, then
`size`. Future slots added by hand-editing are preserved in their
original order on update (Step 5b's byte-faithful replacement
guarantees that).

#### Conditional rendering rules

- A populated slot with `kind: skip` is still emitted under `fields:`
  — it is the user's explicit declaration that the slot is unused,
  which `/issue-*` verbs treat as equivalent to slot-absent but more
  visible. Only omit a slot entirely if the user never reached the
  per-slot interview (e.g. the user aborted out of Step 3b before the
  loop covered that slot).
- If **all** slots are emitted as `kind: skip` or were never reached,
  omit the `fields:` key entirely — the block is still valid without
  it.
- Omit `issue-types` entirely if issue types were skipped or the repo
  has none enabled.
- Preserve the case-sensitive option and type names from the GitHub
  API verbatim — they are the canonical keys the `/issue-*` commands
  match against.
- If any option or type name contains consecutive spaces, or starts
  with a YAML-special character — any of these:

  ```text
  ? : - & * ! [ { , > | % @ ` " '
  ```

  — quote the key with double quotes to keep the YAML well-formed.
  The common case (single-word or space-separated names like `In
  Progress`) is fine unquoted, matching the example in
  `skills/lib/issue.md`. The same quoting rule applies to label
  options inside the `kind: label` flat-list shape: if any option
  contains a YAML-special character or consecutive spaces, quote
  that individual entry with double quotes inside the `[...]` list.

### 3b.6 — Skip marker (when the user chose to skip)

When the user chose `Skip`, `Skip again`, or `Remove`, do not write a
`github-project:` block. Instead, plan to write a single-line HTML
comment of the exact form:

```text
<!-- github-project: intentionally omitted; <reason>. -->
```

Place the comment where the block would have gone (see Step 5b for the
insertion rule). Use the reason captured from the user (free-text
trimmed to a single line, period appended if missing). On `Skip again`
with no reason change, keep the existing marker verbatim.

The skip marker is what makes `/repo-config` re-runs idempotent for
repos that legitimately have no project board: Step 2 detects it,
3b.1 recommends `Skip again`, and the user is not re-asked to
auto-discover something that doesn't exist.

## Step 4: Show the proposed file and wait for approval

Render the resolved YAML front-matter to the user **before** writing
anything. Format it exactly as it will appear in the file:

```yaml
---
source-control: <value>
issues: <value>
issue-link-prefix: "<value>"
default-issue-source-branch: <value>
default-pr-target-branch: <value>
issue-branch-naming-prefix: <value>
---
```

Note: `issue-link-prefix` is always quoted because values like `#`
are otherwise interpreted as a YAML comment.

- If the file does **not** exist, also show the prose body that
  will be written below the front-matter (see Step 5 for the body
  text).
- If the file **does** exist, show a clear diff of the front-matter
  fields that are changing. Use exactly this format — one line per
  changed field, with the key, the literal arrow ` -> `, and the
  new value rendered the way it will appear in the file (quoted for
  `issue-link-prefix`, bare for everything else):

  ```text
  Changes:
    issues: GitHub -> Jira
    issue-link-prefix: "#" -> "SET-"
    default-pr-target-branch: main -> release
  ```

  List only fields whose value actually changed.

### GitHub Project block diff

If Step 3b ran (i.e. `issues == GitHub`), also show what is happening
to the `github-project:` body region. Pick the wording that matches
the planned outcome:

- **No change** (the user chose `Keep`, or chose `Skip again` and
  kept the existing reason): "No `github-project:` change."
- **Add** (no prior block, user populated): show the full proposed
  YAML block exactly as it will appear in the file (the rendered
  block from Step 3b.5), prefixed with the line "Add
  `github-project:` block:".
- **Update** (prior block, user re-discovered): show a unified diff
  of the prior block (literal bytes from Step 2) vs. the proposed
  block, prefixed with "Update `github-project:` block:". For large
  option/type maps, a per-line diff is fine; do not try to be clever.
- **Remove** (prior block, user chose `Remove`): show the line
  "Remove `github-project:` block; replace with skip marker:" and
  print the planned skip-marker comment.
- **Skip first time** (no prior block, user chose `Skip`): show the
  line "Add skip marker:" and print the planned comment.

If nothing changes at all — neither front-matter nor body — say "No
front-matter changes; no `github-project:` change; nothing to
write." and skip Steps 5 and 5b.

The rest of the body (the prose after the optional `github-project:`
region) is preserved verbatim and is not part of the diff.

Then ask explicitly for approval, e.g.:

> Write `.claude/rules/repo-config.md` with the values above? (y to
> proceed, or tell me what to change)

Wait for explicit approval (`y`, `yes`, `go`, `do it`, etc.) before
moving to Steps 5 and 5b. If the user asks for changes, loop back to
Step 3, Step 3b, or Step 4 as appropriate.

## Step 5: Write the file

Use the standard `Write` or `Edit` tool so the diff is visible to
the user.

### New file (file did not exist before)

In a brand-new repo `.claude/` and `.claude/rules/` may not exist
yet. The Claude Code `Write` tool creates missing parent directories
automatically, so calling `Write` on `.claude/rules/repo-config.md`
when neither directory exists is safe. If you are using a different
tool path that does not auto-create parents, run
`mkdir -p .claude/rules` first.

Compose the file in this order:

1. The resolved YAML front-matter (the canonical six-key block from
   Step 4).
2. A blank line.
3. **If Step 3b produced a resolved `github-project:` block**: that
   block exactly as rendered in 3b.5, followed by a blank line. **If
   Step 3b produced a skip marker**: the single-line HTML comment from
   3b.6, followed by a blank line. **If Step 3b ran but the user chose
   to do nothing** or **Step 3b did not run** (Jira): no extra content
   here.
4. The canonical body template (below), starting with `# Repo Config`.

The canonical body template (body only — front-matter and any
github-project content are composed in steps 1-3 above):

````markdown
# Repo Config

Read by `/issue-address` and by the `issue-developer`, `issue-fixer`,
`doc-updater`, and `pr-reviewer` subagents at the start of every run.
Do not assume values are already in context — re-read this file every
time.

## Fields

- **source-control**: `GitHub` or `CodeCommit`. Selects between `gh`
  and `aws codecommit` for VCS operations.
- **issues**: `GitHub` or `Jira`. Selects between `gh issue` and the
  Jira CLI/API for issue operations.
- **issue-link-prefix**: prefix used when referencing an issue in
  commit messages and PR bodies. The orchestrator and agents
  substitute it as a literal string concat: `<issue-link-prefix><N>`.
  For GitHub repos, set this to `#` so references render as `#123`.
  For Jira, use the project key plus dash, e.g. `SET-` (references
  like `SET-123`).
- **default-issue-source-branch**: branch that new issue work
  branches FROM. The orchestrator must pin this when creating the
  feature branch (e.g.
  `git switch -c <name> origin/<source-branch>`) so the branch is
  rooted at the right commit, not at whatever HEAD the worktree
  happened to start on.
- **default-pr-target-branch**: branch that issue PRs target. Often
  the same as `default-issue-source-branch`, but not always.
- **issue-branch-naming-prefix**: branch naming style.
  - `none`     -> `issue-917-slug`
  - `initials` -> `ev/issue-917-slug`
  - `name`     -> `edwin/issue-917-slug`

## Optional: `github-project:` block

This section is **body-only**; it is not part of the six-key
front-matter. Add it below the front-matter when the repo has an
associated GitHub Project V2 board and you want the `/issue-*`
commands (and `/issue-create`'s `--type` / `--importance` / `--status`
flags in particular) to resolve human-readable names to the project's
field IDs and option IDs.

Repos without a project board **omit this block entirely**. The
`/issue-*` commands degrade gracefully: project-specific flags emit a
one-line warning and skip, while non-project operations work
normally.

Schema:

```yaml
github-project:
  project-id: PVT_kwDO...     # ProjectV2 node ID
  fields:
    status:
      kind: single-select
      id: PVTSSF_lADO...      # single-select field ID
      default: Todo
      options:
        Backlog:     <option-id>
        Todo:        <option-id>
        In Progress: <option-id>
        In review:   <option-id>
        Done:        <option-id>
    importance:
      kind: number
      id: PVTF_lADO...        # number-field ID
      default: 3
      min: 1
      max: 9
    size:
      kind: label
      namespace: "size:"
      default: M
      options: [XS, S, M, L, XL]
  issue-types:
    default: Feature
    Bug:     IT_kwDO...
    Feature: IT_kwDO...
    Goal:    IT_kwDO...
    Problem: IT_kwDO...
```

Keys:

- **project-id**: the ProjectV2 node ID (starts with `PVT_`). Find
  with `gh project list --owner <org>` and convert the project
  number to a node ID via GraphQL.
- **fields.\<slot\>.kind**: required discriminator on every populated
  slot. One of `number`, `single-select`, `label`, or `skip`. The
  remaining keys on the slot depend on the kind; see the "Field
  kinds" section of `skills/lib/issue.md` for the per-kind schema and
  examples. There is no implicit default and no backwards-compat
  shim for the old `type:` shape — a repo on the old shape is
  invalid and must be regenerated by re-running `/repo-config`.
- **fields.\<slot\>.id**: for `kind: number` and `kind: single-select`,
  the project field node ID (`PVTF_...` for number fields,
  `PVTSSF_...` for single-select). Find with
  `gh project field-list <project-number> --owner <org>`. Not used
  by `kind: label` (the label name is the identifier) or
  `kind: skip`.
- **fields.\*.default**: optional per-slot default. Resolution order
  for any `/issue-*` flag is: CLI flag > this repo-config default >
  built-in default (Feature / 3 / Todo / current GitHub user).
- **fields.\<number-slot\>.min / .max**: bounds on a `kind: number`
  slot. Out-of-range values abort the verb cleanly rather than
  writing nonsense to the board.
- **fields.\<single-select-slot\>.options**: the human-readable option
  names mapped to their option IDs. The setter verb does a
  case-insensitive match against this map; canonical capitalization
  for display comes from the keys.
- **fields.\<label-slot\>.namespace / .options**: the label namespace
  (e.g. `"size:"`) and a flat list of option suffixes. Concrete
  labels are `<namespace><option>` (e.g. `size:XS`). The verb
  manages the slot via `gh issue edit --add-label/--remove-label`.
- **issue-types**: the human-readable issue-type names mapped to
  their type IDs (`IT_...`). `default:` selects which type
  `/issue-create` uses when `--type` is not passed.

The `/repo-config` skill auto-discovers and populates this block
interactively: pick the project from `gh project list`, then for each
conceptually-standard slot (`status`, `importance`, `size`) the wizard
offers every enumerated project field plus a label-namespace option
and a skip option, and writes `kind:` on every populated slot.
Issue-types are pulled separately via GraphQL. Hand-editing is still
supported — the wizard preserves existing values as recommended
defaults and rewrites the block byte-faithfully against the prior
literal bytes. See `skills/lib/issue.md` for full details on how the
block is consumed.

The Jira branch (`issues: Jira`) gets a parallel `jira:` block when
Jira support is implemented; today, `/issue-*` commands abort under
Jira with the same "not implemented" message `/issue-address` uses.

## Why this file exists

Different repos use different VCS, issue trackers, and branching
strategies. The `/issue-address` orchestrator and its subagents
(`issue-developer`, `issue-fixer`, `doc-updater`, `pr-reviewer`)
must not hardcode assumptions like "PR base is `main`", "use `gh`",
or "issue link is `#NNN`". When a repo deviates, the orchestrator
silently does the wrong thing. This file is the single source of
truth that everything reads at the start of every run.

If this file is missing, `/issue-address` aborts with an error
pointing at this skill (`/repo-config`) to create one
interactively.
````

The body is genericized: it does not reference any specific repo
(such as `macos-setup`) by name, and it points at `/repo-config`
as the way to create the file when it's missing.

### Updating an existing file

When the file already exists there are up to two independent regions
that can change:

1. The **YAML front-matter** (the six keys) — handled in this
   sub-step.
2. The **`github-project:` body region** (the block and/or a skip
   marker) — handled in Step 5b below.

The prose body outside the `github-project:` region is always
preserved byte-for-byte. Do not edit it.

#### 5.a Front-matter

Use the `Edit` tool to replace the front-matter block.

**Build `old_string` from the literal front-matter bytes you read in
Step 2** (opening `---` line through the closing `---` line,
inclusive, with their original line endings and surrounding
whitespace). Do **not** reconstruct `old_string` from the parsed
key/value pairs or from the canonical six-key template shown in
Step 4. Hand-edited files commonly differ from the canonical form
in ways that don't change semantics but break exact-string
matching: keys reordered, extra blank lines between keys, trailing
spaces, comments inserted between keys, single vs. double quoting.
A reconstructed `old_string` will fail to match any of these,
causing `Edit` to error after the user has already completed the
full interview. Reading the existing bytes verbatim and using them
as `old_string` is the only reliable way.

This dovetails with Step 2's "Preserve the body of the file
verbatim" guarantee: the same byte-faithful reading discipline
applies on both sides of the closing `---`.

`new_string` is the freshly rendered six-key block from Step 4
(canonical key order, canonical quoting, no comments, no extra blank
lines). Do not touch the body.

If no front-matter field actually changed, skip this sub-step (no
`Edit` call); the github-project region may still need updating.

## Step 5b: Update the `github-project:` body region (existing file)

This step runs only when the file already existed **and** Step 3b
produced a non-"no change" outcome. New-file writes do not use this
step (Step 5's compose order handles the block inline).

Use the `Edit` tool exactly once per body change, following the same
byte-faithful discipline as Step 5.a's front-matter update.

### Case A: prior block existed; user chose `Update`

- `old_string`: the **literal bytes of the prior block** captured in
  Step 2, including any preceding skip-marker-style comments you
  bundled with the block in Step 2's detect rule. Do not reconstruct
  from parsed values.
- `new_string`: the rendered block from Step 3b.5, with no extra
  surrounding blank lines beyond what the prior bytes had (so the
  surrounding body keeps its original spacing).

### Case B: prior block existed; user chose `Remove`

- `old_string`: the **literal bytes of the prior block** (same as
  Case A).
- `new_string`: the single-line skip-marker comment from Step 3b.6.

### Case C: prior block existed; user chose `Keep`

No `Edit` call. The block stays exactly as it was. (This case is
filtered out by Step 4's "no change" branch and shouldn't reach
Step 5b at all; documented here for completeness.)

### Case D: prior skip marker existed; user chose `Populate`

- `old_string`: the **literal bytes of the prior skip marker**
  captured in Step 2.
- `new_string`: the rendered block from Step 3b.5.

### Case E: prior skip marker existed; user chose `Skip again` with a new reason

- `old_string`: prior skip marker bytes.
- `new_string`: the updated skip marker line.

### Case F: no prior block and no prior skip marker; user chose `Populate` or `Skip`

There is no anchor to use as `old_string` because nothing about the
block currently exists in the file. Pick an insertion anchor and
prepend the new region to it. The anchor is the first non-blank
line in the body — for the canonical body template this is the
`# Repo Config` heading.

To make the anchor unique by construction, always expand it to the
**canonical first two lines** of the body template:

```text
# Repo Config

Read by `/issue-address` and by the `issue-developer`, `issue-fixer`,
```

The phrase "Read by `/issue-address`" is part of the canonical body
template (see Step 5's "canonical body template") and is extremely
unlikely to appear elsewhere in the file. This builds disambiguation
in rather than hinting at it.

- `old_string`: the canonical first two lines of the body, captured
  **verbatim from the file** (so line endings and any trailing
  whitespace match exactly). Concretely, that is the `# Repo Config`
  heading line, the following blank line, and the `Read by ...` line
  that begins the prose body.
- `new_string`: the new block (or skip marker), followed by a single
  blank line, followed by the same captured anchor bytes.

If the file's body deviates from the canonical template — for example,
a hand-edited repo-config whose body starts with something other than
`# Repo Config` followed by the "Read by `/issue-address`" line, or
which has been reordered such that those two lines are not adjacent —
fall back to the general `Edit` disambiguation discipline: extend
`old_string` further with whatever surrounding lines are needed to
make the match unique. Do not write blindly when the anchor cannot
be located unambiguously; surface the situation to the user and stop.

### Verification

After each `Edit` call, re-read the file with `Read` and confirm:

- The block appears at column 0 and parses as YAML.
- The block terminates at a column-0 non-blank line (heading or
  next top-level key) as `skills/lib/issue.md` expects.
- The surrounding body bytes are unchanged outside the edited
  region. (Compare against the bytes you captured in Step 2.)

If verification fails, surface the diff to the user and stop — do
not attempt a corrective second edit. The user should re-run
`/repo-config` after manually resolving the inconsistency.

## Step 6: Summarize

After the file is written, report back:

- The absolute path written.
- The final resolved values for all six front-matter fields.
- The `github-project:` outcome — one of:
  - `populated` (project title and number, count of status options,
    count of issue types).
  - `updated` (same details as `populated`, plus a one-line summary
    of what changed: e.g. "default status Todo -> In Progress; added
    issue type Goal").
  - `kept unchanged` (existing block left as-is).
  - `removed` (block deleted; skip marker written with reason).
  - `skipped` (no block present; skip marker written with reason).
  - `not applicable` (`issues: Jira`, so the block doesn't apply).
- Whether this was a new file or an update.
- Next step: the user can now run `/issue-address` and the
  associated subagents in this repo.

---

## Hard constraints

- **Never write the file without explicit approval** in Step 4.
- **Never edit anything outside the target repo.** The skill writes
  exactly one file: `<repo-root>/.claude/rules/repo-config.md`.
- **Never run destructive git commands.** This skill does not
  commit, push, branch, reset, or otherwise change git state. The
  user commits the new file themselves.
- **Always go through `Edit` or `Write`** so the diff is visible.
- **Do not validate remote branch existence** — out of scope.
- **Do not migrate other config schemas.** If the existing file
  uses unknown keys, surface the problem and stop; do not silently
  drop or rename keys.
- **Do not prompt for `github-project:` under Jira.** Step 3b runs
  only when the just-chosen `issues` value is `GitHub`. Under
  `issues: Jira`, no project block is added, removed, or asked
  about; that branch will eventually get a parallel `jira:` block
  when Jira support lands.
- **Never invent project IDs, field IDs, option IDs, or issue type
  IDs.** All IDs written to the `github-project:` block must come
  from a live `gh` query in Step 3b (or, with explicit user override
  via `Other`, from values the user typed in). Do not copy IDs from
  the schema example in this file or from `skills/lib/issue.md` —
  those are illustrative placeholders.
