# GitHub App resolver (`skills/lib/gh-app.md`)

This file is the single source of truth for how a skill resolves a
GitHub App to use for automated operations (workflow dispatch, branch
protection bypass, commit signing, etc.). It is **reference prose**,
not an executable script: a skill reads it and follows the patterns
documented here. Individual skill files reference this doc rather than
re-deriving the discovery, prompting, or verification logic inline.

The analogous libraries are `skills/lib/repo-config.md` (repo-config
reader contract) and `skills/lib/issue.md` (`/issue-*` shared
reference); this file plays the same role for GitHub App resolution.

## Two paths: find/verify and create-from-scratch

The resolver has two branches:

1. **Find/verify** (this file) -- detect an existing suitable App (or
   ask the user for a name), confirm it has the needed permissions and
   is installed on the target repo, and return the App identity for
   the caller to use.
2. **Create-from-scratch** -- provision a new App when none exists.
   This path is **not implemented here**. It is the domain of the
   `/gh-create-app` skill (tracked in #155). Until that skill is
   built, the create branch instructs the user to create the App
   manually or points them at `/gh-create-app` once it lands.

This split lets setup skills (`/repo-public-mirror-setup`,
`/pr-automation-setup`, `/protection-setup`) run against an
already-existing App without waiting for `/gh-create-app` to be built.

## When to use this library

A skill that needs a GitHub App identity calls the find/verify
sequence documented below as part of its own setup flow. Typical
callers:

- `/repo-public-mirror-setup` -- needs an App to push to the mirror
  repo (deploy key alternative, or for workflow dispatch).
- `/pr-automation-setup` -- needs an App to create PRs, approve, and
  merge on behalf of automation.
- `/protection-setup` -- needs an App identity to list as a bypass
  actor in branch-protection rulesets.

The caller passes:

- **`required_permissions`** -- a map of permission scope to access
  level (e.g. `{ contents: write, pull_requests: write,
  workflows: write }`). The verifier checks these against the App's
  declared permissions.
- **`target_repo`** (optional) -- the `owner/repo` to verify
  installation on. Defaults to the current repo
  (`gh repo view --json nameWithOwner -q .nameWithOwner`).

## Find/verify sequence

### Step 1: Discover candidate Apps

List GitHub Apps installed on the target repo's organization (or
user account):

```bash
gh api "/orgs/__GH_ORG__/installations" --jq \
  '.installations[] |
   {id, app_slug, app_id, permissions}'
```

If the org endpoint returns a 404 (user account, not an org), fall
back to:

```bash
gh api "/users/__GH_ORG__/installations" --jq \
  '.installations[] |
   {id, app_slug, app_id, permissions}'
```

Parse the JSON output into a list of candidate installations.

If neither endpoint returns any installations, proceed to Step 3
(no candidates).

### Step 2: Filter by permissions

For each candidate, check that every entry in `required_permissions`
is satisfied:

```text
for each (scope, level) in required_permissions:
  candidate.permissions[scope] must be >= level
  ("read" < "write" < "admin" for comparison purposes)
```

Candidates that pass all checks are **suitable**. Keep track of which
candidates fail and why (the missing/insufficient permission) for the
report in Step 3.

### Step 3: Select or prompt

Three cases:

- **Exactly one suitable candidate** -- use it. Print the selection
  for the user:

  > Using GitHub App `<app_slug>` (ID `<app_id>`,
  > installation `<installation_id>`).

- **Multiple suitable candidates** -- present the list and ask the
  user to pick one:

  > Found multiple GitHub Apps with sufficient permissions:
  >
  > 1. `<app_slug_1>` (ID `<app_id_1>`)
  > 2. `<app_slug_2>` (ID `<app_id_2>`)
  >
  > Which App should this skill use?

  Use the user's choice for the rest of the flow.

- **No suitable candidates** -- two sub-cases:

  - **Candidates exist but none have sufficient permissions** --
    report what was found and what was missing:

    > No installed GitHub App has sufficient permissions for this
    > skill. Required: `<required_permissions>`.
    >
    > Found Apps:
    > - `<app_slug>`: missing `<scope>: <level>` (has `<actual>`
    >   or not granted)
    >
    > Create a suitable App with `/gh-create-app` (not yet
    > implemented -- see #155), or create one manually and re-run
    > this skill.

  - **No installations at all** -- report and point at the create
    path:

    > No GitHub Apps installed on `<org>`. Create one with
    > `/gh-create-app` (not yet implemented -- see #155), or
    > create one manually and re-run this skill.

  In both sub-cases, abort the calling skill. The user needs to
  create or reconfigure an App before the skill can proceed.

### Step 4: Verify installation on the target repo

Confirm the chosen App is installed on the specific target repo (not
just the org):

```bash
gh api "/repos/__GH_ORG__/__GH_REPO__/installation" \
  --jq '{id: .id, app_id: .app_id, app_slug: .app_slug}'
```

If this returns a 404 or the returned `app_id` does not match the
chosen App, the App is installed on the org but not configured for
this repo. Report:

> GitHub App `<app_slug>` is installed on `<org>` but not configured
> for `<org>/<repo>`. Update the App's repository access settings to
> include this repo, then re-run the skill.

Abort the calling skill.

### Step 5: Return the resolved identity

Return to the caller:

```text
app_slug:        <app_slug>
app_id:          <app_id>
installation_id: <installation_id>
```

The caller uses these values to configure workflows, branch-protection
bypass actors, or any other integration that needs the App identity.

## User-supplied App name (skip discovery)

A skill may accept an App name as an explicit input (e.g.
`--app-name <slug>`). When provided, the skill skips Steps 1-3 and
goes directly to verification:

1. Look up the App by slug:

   ```bash
   gh api "/repos/__GH_ORG__/__GH_REPO__/installation" \
     --jq '{id: .id, app_id: .app_id, app_slug: .app_slug}'
   ```

2. Verify the returned `app_slug` matches the user-supplied name
   (case-insensitive). If not, abort:

   > The App installed on `<org>/<repo>` is `<actual_slug>`, not
   > `<expected_slug>`. Check the App name and try again.

3. Check that the App's permissions satisfy `required_permissions`
   using the same logic as Step 2 above. If insufficient, abort with
   the same "missing permissions" report.

4. Return the resolved identity (Step 5).

## Placeholder values derived from an App

When a resolved App identity is used in template rendering (see
`.global-claude-config/README.md` for the placeholder convention),
the following placeholders map to the resolved values:

| Placeholder | Source |
| --- | --- |
| `__APP_NAME__` | `app_slug` |
| `__APP_ID__` | `app_id` |

## Create-from-scratch path (stub)

The create path is tracked in #155 (`/gh-create-app`). Until that
skill is implemented:

- Skills that reach the "no suitable candidates" branch in Step 3
  print the pointer message shown there and abort.
- Skills must not attempt to create a GitHub App programmatically
  from this library. The App-creation flow involves manifest
  registration, webhook configuration, and private-key handling that
  require a dedicated skill with its own approval gates.

When `/gh-create-app` lands, this section will be updated to document
the handoff: this library calls `/gh-create-app` with the
`required_permissions` map, receives the new App identity, and
continues from Step 4 (verify installation).

## Conventions for callers

When writing a skill that consumes this library:

- Open with a statement of which permissions the skill requires
  (the `required_permissions` map).
- Reference this file: "See `skills/lib/gh-app.md` for the
  find/verify sequence."
- Do not duplicate the find/verify logic inline -- reference the
  steps by number ("run Steps 1-5 from `skills/lib/gh-app.md`
  with `required_permissions = { ... }`").
- Do not invent alternative discovery mechanisms. If the `gh api`
  endpoints documented here are insufficient for a new use case,
  update this library rather than working around it in the caller.
