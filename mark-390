---
name: repo-config
description: Interactively create or fully rewrite `.claude/rules/repo-config.md` by interviewing the user about VCS, issue tracker, and (for GitHub repos) the associated Project V2 board.
---

You are running the `/repo-config` skill. Your job is to create the
**target repo's** `.claude/rules/repo-config.md` from scratch, or to
fully rewrite it when it already exists, by interviewing the user.
This file is read by `/issue-address` and the `issue-developer`,
`issue-fixer`, `doc-updater`, and `pr-reviewer` subagents at the
start of every run, so it must be present and well formed before
any of those flows will work.

`/repo-config` does **not** merge with the existing file, retain
its values as defaults, or rewrite parts of it in place. When the
file already exists, the user confirms an overwrite up front in
Step 2.5; the final write in Step 5 replaces the entire file with
content built from the user's answers in the current run. The
recommended option for every interview question is the built-in
default baked into this skill, never a value carried over from the
prior file. If the user wants the prior file's contents preserved,
they decline the Step 2.5 overwrite prompt and the file is left
untouched.

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

`/repo-config` is a **full-rewrite** tool. It does not parse the
existing file's values into recommended defaults, and it does not
preserve the existing body verbatim. The final write in Step 5
replaces the entire file with content assembled from the user's
answers in this run. The previous file's content is discarded once
the user confirms the overwrite in Step 2.5.

- **If it exists**: read the file's full contents into memory so
  Step 2.5 can display them to the user before they decide whether
  to overwrite. Do **not** parse the front-matter into recommended
  defaults. Do **not** scan for a `github-project:` block or skip
  marker to seed defaults. The bytes are read for display only;
  they will be discarded if the user confirms overwrite.
- **If it does not exist**: nothing to read; proceed straight to
  Step 3.

In both cases, the recommended option for every interview question
in Step 3 (and Step 3b) is the **built-in default** baked into this
skill, not anything from the existing file. The built-in front-matter
defaults are:

- `source-control`: `GitHub`
- `issues`: `GitHub`
- `issue-link-prefix`: `#`
- `default-issue-source-branch`: `main`
- `default-pr-target-branch`: `main`
- `issue-branch-naming-prefix`: `none`

`schema-version` is **not** in this list — it is a write-time
constant (currently `6`) baked into this skill, not an interview
question. See `skills/lib/repo-config.md` for the reader contract
that consumes it.

Also, before Step 3, gather the local branch list with
`git branch --format='%(refname:short)'` so you can offer real
branches as options for the two branch fields.

## Step 2.5: Confirm overwrite (existing file only)

This step runs **only if the file existed** in Step 2. If the file
did not exist, skip directly to Step 3.

`/repo-config` rewrites the entire file from the user's answers in
this run. Before running the interview — which is wasted effort if
the user actually wanted to inspect, not overwrite — confirm intent
with a single overwrite prompt.

1. Display the **full current contents** of
   `.claude/rules/repo-config.md` to the user — front-matter and
   body, byte-for-byte as read from disk. Do not paraphrase or
   summarize; the user is deciding whether to discard the real file.
2. Ask via `AskUserQuestion`: "This will replace
   `.claude/rules/repo-config.md` with a fresh file built from your
   answers — continue?" with options `Yes` and `No`.
3. **On `No`**: end the skill cleanly. Report that the file was
   left unchanged at `<repo-root>/.claude/rules/repo-config.md`.
   Do **not** enter the interview. Do **not** write or edit
   anything. Skip Steps 3 through 6.
4. **On `Yes`**: continue into Step 3. From this point on, treat
   the existing file's contents as discarded — every interview
   question recommends the **built-in default**, never a value
   carried over from the prior file.

## Step 3: Interview

Use the `AskUserQuestion` tool to interview the user. Ask the six
fields **in the order below**. Group them into multiple
`AskUserQuestion` calls as feels natural — the tool allows 1–4
questions per call, and exact grouping is left to your judgment.

For every question:

- The **first option** must be the recommended value (the built-in
  default for the field as listed below), with its label suffixed
  `(Recommended)`. The recommendation never comes from the previous
  file's contents — even when the file existed, those contents were
  discarded in Step 2.5.
- Always include an "Other" option so the user can type a custom
  value.
- Keep option labels short; put any explanation in the question
  text.

The six fields, in order:

1. **`source-control`** — choose `GitHub` or `CodeCommit`.
   Recommend `GitHub`.
2. **`issues`** — choose `GitHub` or `Jira`. Recommend `GitHub`.
3. **`issue-link-prefix`** — the literal string concatenated with
   the issue number in commit messages and PR bodies. The recommended
   value depends on the **just-chosen** value of `issues` (field 2).
   - If the user picked `GitHub` for `issues`, recommend `#`
     (`#123` is the only sensible GitHub form).
   - If the user picked `Jira` for `issues`, do not pre-recommend a
     value — prompt the user to enter the Jira project key plus a
     trailing dash via "Other" (e.g. `SET-`, `PROJ-`).
4. **`default-issue-source-branch`** — branch that new issue work
   branches FROM. Offer the local branches you gathered in Step 2
   as options, plus "Other" for any branch name. Recommend `main`
   if it is present in the local branch list; otherwise present the
   gathered branches without a recommendation and require the user
   to pick.
5. **`default-pr-target-branch`** — branch that issue PRs target.
   Same option set as field 4. Recommend whatever the user just
   chose for `default-issue-source-branch` (often the same).
6. **`issue-branch-naming-prefix`** — branch naming style.
   Choose one of `none`, `initials`, `name`. Recommend `none`.

Do not validate that the chosen branches actually exist on the
remote; that is out of scope for this skill.

## Step 3b: GitHub Project interview (conditional)

This step runs **only when the just-chosen `issues` value is `GitHub`**.
If `issues` is `Jira` (or anything other than `GitHub`), skip this
step entirely and proceed to Step 4. Do not prompt for any
project-related values under Jira; the `github-project:` block is a
GitHub-only concept and the Jira branch will eventually get a parallel
`jira:` block.

The purpose of this step is to populate (or intentionally omit) the
`github-project:` body block defined in `skills/lib/issue.md`. The
block carries project node IDs, status option IDs, and issue type
IDs so the `/issue-*` commands can translate human-readable names
into the GraphQL IDs the GitHub API requires.

Because `/repo-config` is a full-rewrite tool (see Step 2), this
step always starts from scratch: any prior `github-project:` block
or skip marker in the existing file was discarded in Step 2.5.

### 3b.1 — Decide whether to populate

Use `AskUserQuestion` to ask the user how to handle the
`github-project:` block. Offer two options:

- **Populate** — recommended. Run auto-discovery (Steps 3b.2 – 3b.5)
  and build the block from scratch.
- **Skip** — do not add a block. Write a skip marker instead with a
  short reason captured via "Other". Skip the rest of Step 3b
  except 3b.6 (which writes the marker).

There is no `Keep` / `Update` / `Skip again` option set in this skill:
the file is being rewritten, so there is no prior block to keep or
re-update, and no prior skip marker to carry forward. If the user
wants the previous block back verbatim, they should answer `No` at
the Step 2.5 overwrite prompt and the file stays untouched.

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
  # Replace `organization(login:)` with `user(login:)` if the owner
  # is a user account, not an organization.
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

`dataType` is one of `NUMBER`, `TEXT`, `DATE`, `SINGLE_SELECT`,
`ITERATION`, `TITLE`, `ASSIGNEES`, `LABELS`, `MILESTONE`,
`REPOSITORY`, `REVIEWERS`, `LINKED_PULL_REQUESTS`, `TRACKS`,
`TRACKED_BY`.

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
   kind to pick, in this order:
   1. A **number** field named `Importance` or `Priority`
      (case-insensitive). If exactly one such field exists, recommend
      it.
   2. Otherwise a **single-select** field with the same name. If
      exactly one such field exists, recommend it.
   3. Otherwise no auto-recommendation — present the full option set
      and let the user pick.

   If multiple fields match at the same tier (e.g. both an
   `Importance` and a `Priority` number field), present all of them as
   options and let the user pick; do not silently prefer one.
3. **`size`** — optional. Default-recommendation chain for which kind
   to pick, in this order:
   1. A **single-select** field named `Size` or `T-Shirt`
      (case-insensitive). If exactly one such field exists, recommend
      it.
   2. Otherwise a **number** field with the same name. If exactly one
      such field exists, recommend it.
   3. Otherwise recommend `kind: label` with namespace `size:` (the
      built-in fallback for repos with no project field for size).

   If multiple single-select fields match (e.g. both `Size` and
   `T-Shirt`), present them as options and let the user pick — no
   auto-recommendation.

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
  and is rendered as `kind: skip`. Per `skills/lib/issue.md`'s "Field
  kinds" section, an emitted `kind: skip` and a slot-absent entry are
  intentionally equivalent in verb behavior; the wizard always emits
  `kind: skip` for visibility. The slot-absent path only occurs when
  the user never reached the per-slot interview at all (e.g. they
  chose `Skip` at the block level in Step 3b.1).

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
  - Ask for `default` (integer or float). No built-in recommendation
    — the user owns the value.
  - Ask for `min` (integer or float). No built-in recommendation —
    the user owns the range.
  - Ask for `max` (integer or float). No built-in recommendation —
    the user owns the range.

- **Single-select field** (`kind: single-select`):
  - Capture the field `id` (`PVTSSF_...`) and the full option
    name→id map from the enumeration.
  - Ask which option should be the **default** for new issues. The
    recommendation chain is slot-aware:
    - For `status`: `Backlog` if present (case-insensitive), then
      the first option in the list.
    - For other slots: the first option in the list.
  - Always include an `Other` choice to free-type one of the
    enumerated option names.

- **Labels** (`kind: label`):
  - Ask for the **namespace prefix**. Recommend `<slot>:` (e.g.
    `size:` for the `size` slot). Free-text via `Other` for any other
    value; trailing colon is conventional but not enforced by the
    wizard.
  - Ask for the **option list** as a comma-separated string (e.g.
    `XS, S, M, L, XL`). No built-in recommendation — the user owns
    the list. Split on commas, trim whitespace from each entry;
    reject empty entries.
  - Ask for the **default** option (must be one of the entered
    options, case-insensitive match against the list). Recommend
    the first entry in the list.
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
order: `Feature` (if present, case-insensitive), then the first
type in the list. Include `Other` for free-type.

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

Slot order under `fields:` is fixed: `status`, then `importance`,
then `size`. Because `/repo-config` is a full-rewrite tool, the
emitted block is exactly what this run's auto-discovery produced —
any hand-edited slot the wizard doesn't know about (e.g. a
user-added `priority` or `effort` slot) is dropped. Users who want
to preserve hand-edited slots should decline the Step 2.5 overwrite
prompt and hand-edit instead.

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

When the user chose `Skip` in 3b.1, do not write a `github-project:`
block. Instead, plan to write a single-line HTML comment of the
exact form:

```text
<!-- github-project: intentionally omitted; <reason>. -->
```

Place the comment where the block would have gone (see Step 5's
compose order). Use the reason captured from the user (free-text
trimmed to a single line, period appended if missing).

The skip marker documents the deliberate omission so anyone reading
the file later knows it was a choice, not an oversight. Subsequent
`/repo-config` runs do not read it as a default — the file is
rewritten from scratch every time — but the next user inspecting
the file via Step 2.5's display will see the prior reason and can
re-enter it if they choose `Skip` again.

## Step 4: Show the proposed file and wait for approval

Render the **full file** that will be written, exactly as it will
appear on disk. This applies equally to the new-file case and the
overwrite case — there is no diff path, because Step 5 always
performs a full-file write and discards the previous contents.

Compose the preview in the same order Step 5 will write it:

1. The resolved YAML front-matter (the canonical seven-key block):

   ```yaml
   ---
   schema-version: 6
   source-control: <value>
   issues: <value>
   issue-link-prefix: "<value>"
   default-issue-source-branch: <value>
   default-pr-target-branch: <value>
   issue-branch-naming-prefix: <value>
   ---
   ```

   Notes:

   - `schema-version` is **always the first key** and **always
     `6`** in files this skill writes. It is a constant baked
     into the writer, not an interview question — see
     `skills/lib/repo-config.md` for how readers consume it.
     When the schema bumps, update this skill's constant, the
     library's `SCHEMA_VERSION`, and each reader's pinned
     version in lockstep.
   - `issue-link-prefix` is always quoted because values like
     `#` are otherwise interpreted as a YAML comment.

2. A blank line.

3. **If Step 3b produced a `github-project:` block** (user chose
   `Populate`): the rendered block from 3b.5, followed by a blank
   line. **If Step 3b produced a skip marker** (user chose `Skip`):
   the single-line HTML comment from 3b.6, followed by a blank line.
   **If Step 3b did not run** (Jira branch): no extra content here.

4. The canonical body template (the same `# Repo Config` ... body
   used in Step 5).

Then ask explicitly for approval, e.g.:

> Write `.claude/rules/repo-config.md` with the content above? (y
> to proceed, or tell me what to change)

Wait for explicit approval (`y`, `yes`, `go`, `do it`, etc.) before
moving to Step 5. If the user asks for changes, loop back to Step
3 or Step 3b as appropriate, then re-render the full file in this
step.

## Step 5: Write the file

Use the `Write` tool to replace the entire file in a single call.
This applies whether the file existed before or not — `/repo-config`
is a full-rewrite tool, and the user already saw the full proposed
contents in Step 4 before approving.

Do not use `Edit` for in-place region rewrites. Do not preserve any
bytes from the previous file. The previous contents were discarded
in Step 2.5; the new file's content is determined entirely by the
user's answers in this run plus the canonical body template below.

In a brand-new repo `.claude/` and `.claude/rules/` may not exist
yet. The Claude Code `Write` tool creates missing parent directories
automatically, so calling `Write` on `.claude/rules/repo-config.md`
when neither directory exists is safe. If you are using a different
tool path that does not auto-create parents, run
`mkdir -p .claude/rules` first.

Compose the file in this order:

1. The resolved YAML front-matter (the canonical seven-key block
   from Step 4 — `schema-version: 6` followed by the six
   user-resolved fields, in that exact order).
2. A blank line.
3. **If Step 3b produced a resolved `github-project:` block**: that
   block exactly as rendered in 3b.5, followed by a blank line. **If
   Step 3b produced a skip marker**: the single-line HTML comment
   from 3b.6, followed by a blank line. **If Step 3b did not run**
   (Jira): no extra content here.
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

- **schema-version**: integer naming the file's schema version.
  The current version is `6`. The writer (`/repo-config`) stamps
  it into every file it produces; readers (see
  `skills/lib/repo-config.md`) consult it and abort cleanly when
  the value is missing or older than they require. Do not edit
  this by hand — re-run `/repo-config` to migrate to a newer
  version.
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

This section is **body-only**; it is not part of the seven-key
front-matter. Add it below the front-matter when the repo has an
associated GitHub Project V2 board and you want the `/issue-*`
commands (and `/issue-create`'s `--type` / `--importance` / `--size`
/ `--status` flags in particular) to resolve human-readable names to
the project's field IDs and option IDs.

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
      default: Backlog
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

The `importance` block's `min: 1` / `max: 9` values above are
illustrative — the wizard prompts the user for those and does not
auto-fill them.

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
  for `/issue-create`'s slot flags (`--importance`, `--size`,
  `--status`) is: CLI flag > interactive prompt > this repo-config
  default > slot-skip. The interactive prompt rung shows the user
  the slot's options with this `default:` as the recommended /
  first option (or, for `--size`, the model's read of the issue
  body — see `skills/lib/issue.md` "Interactive prompt rung" and
  the "Size evaluation heuristic" in
  `skills/issue-create/SKILL.md`). Set-slot verbs
  (`/issue-set-importance`, `/issue-set-size`, `/issue-set-status`)
  do not consult this `default:` — they require an explicit
  `<value>` positional argument. Slot flags have no built-in
  default — if none of CLI flag, interactive prompt, or this
  `default:` produces a value, the slot is skipped per "Graceful
  degradation" in `skills/lib/issue.md`. The non-slot built-in
  defaults (`--type` = `Feature`, `--assignee` = current GitHub user,
  `--labels` = none, `--parent` = none) still apply to their
  respective flags.
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
Issue-types are pulled separately via GraphQL. Hand-editing is
supported, but `/repo-config` is a full-rewrite tool: re-running it
will replace this entire file with content built from your answers
in that run, discarding any hand edits. To keep hand edits, decline
the overwrite prompt at the start of the next run. See
`skills/lib/issue.md` for full details on how the block is consumed.

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

### Verification

After the `Write` call, re-read the file with `Read` and confirm:

- The front-matter parses as YAML and contains exactly the seven
  canonical keys: `schema-version: 6` (first) followed by the six
  fields with the values the user approved in Step 4.
- If Step 3b produced a `github-project:` block, the block appears
  at column 0 and parses as YAML; it terminates at a column-0
  non-blank line (heading or next top-level key) as
  `skills/lib/issue.md` expects.
- The canonical body template is present below the front-matter
  (and below the `github-project:` block, if any).

If verification fails, surface the discrepancy to the user and stop
— do not attempt a corrective second write. The user should re-run
`/repo-config` after manually resolving the inconsistency.

## Step 6: Summarize

After the file is written, report back:

- The absolute path written.
- The final resolved values for all six front-matter fields.
- The `github-project:` outcome — one of:
  - `populated` (project title and number, count of status options,
    count of issue types).
  - `skipped` (no block present; skip marker written with reason).
  - `not applicable` (`issues: Jira`, so the block doesn't apply).
- Whether the prior file (if any) was replaced. If the user
  declined the Step 2.5 overwrite prompt, this step is not reached
  — the skill exits in Step 2.5 with a "left unchanged" message.
- Next step: the user can now run `/issue-address` and the
  associated subagents in this repo.

---

## Hard constraints

- **Never write the file without explicit approval** in Step 4.
- **Never overwrite an existing file without the Step 2.5
  confirmation.** If the user declines, exit cleanly and leave the
  file untouched.
- **Never carry values forward from the existing file.** Recommended
  defaults always come from this skill's built-in defaults or from
  values the user enters in the current run, never from the
  previous file's contents. Reading the prior file is for display
  only (Step 2.5).
- **Never edit anything outside the target repo.** The skill writes
  exactly one file: `<repo-root>/.claude/rules/repo-config.md`.
- **Never run destructive git commands.** This skill does not
  commit, push, branch, reset, or otherwise change git state. The
  user commits the new file themselves.
- **Always go through `Write`** so the user sees the new contents
  applied as a single diff. Do not use `Edit` to rewrite regions
  of the prior file — the file is always replaced in full.
- **Do not validate remote branch existence** — out of scope.
- **Do not prompt for `github-project:` under Jira.** Step 3b runs
  only when the just-chosen `issues` value is `GitHub`. Under
  `issues: Jira`, no project block is added or asked about; that
  branch will eventually get a parallel `jira:` block when Jira
  support lands.
- **Never invent project IDs, field IDs, option IDs, or issue type
  IDs.** All IDs written to the `github-project:` block must come
  from a live `gh` query in Step 3b (or, with explicit user override
  via `Other`, from values the user typed in). Do not copy IDs from
  the schema example in this file or from `skills/lib/issue.md` —
  those are illustrative placeholders.
