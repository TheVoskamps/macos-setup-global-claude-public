# Repo-config reader contract (`skills/lib/repo-config.md`)

This file is the single source of truth for how readers should
consume `.claude/rules/repo-config.md`. It is **reference prose**,
not an executable script: a reader (orchestrator, subagent, or
skill) follows the patterns documented here when it loads the
target repo's config. Individual readers reference this doc rather
than re-deriving the parse rules or abort wording.

The analogous library for the `/issue-*` namespace is
`skills/lib/issue.md`; this file plays the same role for the
repo-config file itself.

## Current schema version

```text
SCHEMA_VERSION = 6
```

`6` is the version readers should require as of this writing. A
reader pins the version it knows how to consume in its own code
(see "Reader-side version pin" below) and aborts cleanly when the
target file is older. The writer (`/repo-config`) stamps `6` into
every file it produces; see `skills/repo-config/SKILL.md`.

Why a constant rather than a range:

- The schema-version is a single integer, not a `[min, max]`
  interval. Readers don't accept "anything ≥ N" — they accept
  exactly the version they were written against, and a re-run of
  `/repo-config` migrates older files to the current shape.
- Every bump to the schema is paired with a writer update and a
  bump to this constant. Readers that need an older shape should
  pin their own required version and refuse to upgrade silently.

## What the file looks like

`.claude/rules/repo-config.md` has three parts, in order:

1. A YAML front-matter block, delimited by `---` on the line above
   and the line below. Contains a fixed set of top-level keys: a
   `schema-version:` integer (first key, since version `6`) and
   the six canonical front-matter fields documented under
   "Front-matter fields" below.
2. A body. Everything after the closing `---`. The body may
   contain an optional `github-project:` block (parsed as YAML at
   column 0) and a prose section that documents the file's own
   fields. The prose is for humans reading the file directly; it
   is not part of the read contract.
3. (Optional) A single-line skip marker HTML comment in place of
   the `github-project:` block when the repo author deliberately
   omitted it. See "Skip marker" below.

## Canonical read sequence

Every reader of `.claude/rules/repo-config.md` follows this exact
sequence. Each numbered step has a single canonical abort message
(see "Abort messages" below); use the wording verbatim so the
namespace presents consistent errors.

1. **Locate the file.** Find the repo root with
   `git rev-parse --show-toplevel`. The file lives at
   `<repo-root>/.claude/rules/repo-config.md`. Do not assume the
   caller's cwd is the repo root.

2. **Read the file.** If the file is absent, abort with the
   "File missing" message.

3. **Parse the front-matter.** Find the opening `---` (the file's
   first non-blank line) and the closing `---`. Parse the lines
   between them as YAML. If the front-matter block is malformed or
   absent, treat it as schema-version `0` and abort with the
   "Schema-version absent" message.

4. **Check `schema-version`.**
   - If the `schema-version` key is absent from the parsed
     front-matter, treat its value as `0` and abort with the
     "Schema-version absent" message.
   - If the parsed value is an integer less than the reader's
     required version, abort with the "Schema-version stale"
     message, naming both the file's version and the required
     version.
   - If the parsed value equals the reader's required version,
     proceed.
   - If the parsed value is **greater than** the reader's required
     version, the reader was written against an older schema than
     the target file. Today's policy is to proceed and read only
     the fields documented here — newer schema versions are
     forward-compatible by construction (additive). A future
     breaking-change bump may revisit this; until then, do not
     abort on a higher-than-required version.

5. **Read front-matter fields.** Pull the six canonical fields
   (see "Front-matter fields" below). Missing fields are a
   schema-version mismatch by construction (a `schema-version: 6`
   file is required to populate all six); treat any missing field
   as a stale-schema abort.

6. **(Optional) Read the `github-project:` block.** Scan the body
   for a line that starts with `github-project:` at column 0. If
   present, parse the indented YAML beneath it per the schema
   documented in `skills/lib/issue.md`. If absent, the reader
   gracefully degrades per the "Graceful degradation when the
   block is missing" section of `skills/lib/issue.md`. Skip-marker
   HTML comments (see below) count as "absent" for read purposes.

7. **Return resolved values.** Hand the parsed values back to the
   caller. Do not cache across runs — readers re-read the file
   every time so that a re-run of `/repo-config` between calls is
   picked up immediately.

### Reader-side version pin

A reader pins the schema-version it requires as a constant in its
own code. For prose-defined readers (subagent definitions, skill
SKILL.md files), the constant is a literal in the reader's text;
for any future executable reader, it would be a code constant.

The pinned value should equal the version this library documents
at the time the reader was written. When the schema bumps:

1. The writer (`/repo-config`) bumps its emitted value.
2. This library bumps `SCHEMA_VERSION` to match.
3. Each reader bumps its own pin in lockstep, in the same PR or a
   tightly-scoped follow-up.

Readers that lag the bump abort cleanly per the "Schema-version
stale" message; they do not silently read a newer file.

## Abort messages

Use these exact wordings so every reader emits the same error.
Variable parts are wrapped in backticks.

- **File missing**

  > This repo has no `.claude/rules/repo-config.md`. Run
  > `/repo-config` to create one.

  Some existing readers prefix this with a reader-specific clause
  ("issue-developer requires it", "/issue-* commands require it",
  etc.). The clause is permitted but not required; the
  `Run /repo-config to create one` tail is the canonical fix
  hint.

- **Schema-version absent**

  > This repo's `.claude/rules/repo-config.md` predates schema
  > versioning. Run `/repo-config` to migrate.

  Triggered when the front-matter has no `schema-version:` key (or
  the front-matter itself is malformed/absent). Treated as
  schema-version `0`; the user fixes it by re-running
  `/repo-config`, which will overwrite the file with the current
  shape.

- **Schema-version stale**

  > This repo's `.claude/rules/repo-config.md` is at
  > schema-version `<N>`; this skill requires `<M>`. Run
  > `/repo-config` to migrate.

  Triggered when the parsed `schema-version` integer is less than
  the reader's required version. `<N>` is the file's current
  version, `<M>` is the reader's required version. The fix is the
  same — re-run `/repo-config` to overwrite the file.

Readers should not invent additional abort messages for the same
failure shapes. If a new failure shape arises, document it in this
catalogue rather than ad-hoc wording in the reader.

## Front-matter fields

The six canonical front-matter fields, alongside `schema-version`,
make up the seven keys that appear in every `schema-version: 6`
file. Order is fixed; `schema-version` is always first.

- **`schema-version`** — integer. The file's schema version. As
  of this writing the only valid value is `6`. Readers consult
  this field per the canonical read sequence above. The writer
  (`/repo-config`) emits the current version as a constant; users
  do not edit it by hand. Older or absent values trigger the
  abort messages above.

- **`source-control`** — `GitHub` or `CodeCommit`. Selects between
  `gh` and `aws codecommit` for VCS operations. The
  `issue-developer`, `issue-fixer`, and `pr-reviewer` agents
  dispatch on this value when creating PRs / opening reviews.

- **`issues`** — `GitHub` or `Jira`. Selects between `gh issue`
  and the Jira CLI/API for issue operations. Today, `Jira`
  triggers a "not implemented" abort across `/issue-*` and
  `/issue-address`; that abort message lives in `skills/lib/issue.md`
  (the "Jira backend not implemented" entry).

- **`issue-link-prefix`** — string. The literal string
  concatenated with an issue number in commit messages and PR
  bodies. The orchestrator and agents substitute it as
  `<issue-link-prefix><N>`. For GitHub repos, `#` so references
  render as `#123`; for Jira, the project key plus dash
  (e.g. `SET-` for `SET-123`). Quote the value in YAML if it
  starts with `#` (otherwise YAML parses it as a comment) —
  `/repo-config` does this automatically.

- **`default-issue-source-branch`** — string. Branch that new
  issue work branches FROM. The orchestrator pins this when
  creating the feature branch (e.g.
  `git switch -c <name> origin/<source-branch>`) so the branch
  is rooted at the right commit, not at whatever HEAD the
  worktree happened to start on.

- **`default-pr-target-branch`** — string. Branch that issue PRs
  target. Often the same as `default-issue-source-branch`, but
  not always (e.g. release-branch workflows where work branches
  off `integ` but PRs target `main`).

- **`issue-branch-naming-prefix`** — one of `none`, `initials`,
  `name`. Selects the branch-name shape that `/issue-address`
  and the developer/fixer agents use:
  - `none`     -> `issue-<N>-<slug>`
  - `initials` -> `<initials>/issue-<N>-<slug>`
  - `name`     -> `<name>/issue-<N>-<slug>`

  When the prefix is `initials` or `name`, the agent prompts the
  human owner for the value if the spawn context doesn't supply it.

### Per-field accessor pattern

Readers that need a single field follow this shape (prose
pseudocode; the actual reader is whatever language fits):

```text
config = read_repo_config(required_version = <N>)   # the seven steps above
branch = config["default-issue-source-branch"]
```

The read step does the schema-version check once; per-field
accessors are plain dictionary lookups on the resolved value. Do
not re-parse the file per field.

## `github-project:` block

The `github-project:` block lives in the body, parsed as YAML at
column 0. Its schema (project ID, per-slot field configuration,
issue-types map) is documented in full under "Repo-config parsing"
and "Field kinds (`fields.<slot>.kind`)" in `skills/lib/issue.md`.
This library does not duplicate that schema; readers needing the
block should follow the parse rules there.

The block is **optional**. Repos without a Project V2 board omit
it entirely. The `/issue-*` namespace degrades gracefully when the
block is absent, per `skills/lib/issue.md` "Graceful degradation
when the block is missing". This library's canonical read
sequence (step 6) covers the absent-block case by deferring to
that section.

### Skip marker

When a repo author deliberately omits the `github-project:` block,
`/repo-config` writes a single-line HTML comment in its place:

```text
<!-- github-project: intentionally omitted; <reason>. -->
```

For read purposes, the skip marker is equivalent to "block
absent" — readers do not parse the reason, do not surface it in
error messages, and do not change behavior based on its presence.
The marker exists so a human reading the file can see the
omission was deliberate. A subsequent `/repo-config` run does not
read the marker as a default either; the file is rewritten from
scratch every time.

## Migration policy

This issue introduces `schema-version: 6` and this library, but
does **not** migrate existing readers. The four agent definitions
(`issue-developer`, `issue-fixer`, `doc-updater`, `pr-reviewer`),
`/issue-address`'s SKILL.md, and the `/issue-*` namespace's
existing parsing all keep their ad-hoc reads. Reader migrations
land in their own follow-up issues.

When migrating a reader:

1. Add the reader's required-version constant alongside its
   existing parse logic.
2. Replace ad-hoc abort wording with the canonical messages from
   "Abort messages" above.
3. Replace ad-hoc YAML parsing with a call to (or in-prose
   description of) the canonical read sequence.
4. Update the reader's frontmatter or top-of-file comment to
   reference this library, the same way `skills/lib/issue.md`
   readers do.

Readers that are not yet migrated keep working — they parse the
front-matter ad-hoc and never look at `schema-version`. A
`schema-version: 6` file is fully readable by them because the
six canonical front-matter fields are unchanged from the
pre-versioned shape.

## Conventions for readers

When writing or updating a reader of `.claude/rules/repo-config.md`:

- Open with a one-line statement of which schema-version the
  reader requires.
- Reference this file: "See `skills/lib/repo-config.md` for the
  read contract and abort messages."
- Do **not** restate the canonical abort wording inline — quote it
  from this file by exact wording. If the reader needs a
  reader-specific prefix (e.g. "issue-developer requires it"),
  prepend it but leave the canonical tail intact.
- Do **not** invent a new schema-version mismatch wording.
- Re-read the file every run. Do not cache parsed values across
  invocations; a re-run of `/repo-config` between two reads must
  be picked up.
