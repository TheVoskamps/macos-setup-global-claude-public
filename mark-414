---
name: repo-public-mirror-setup
description: Bootstrap a filtered, read-only public mirror for the current private repo (paired public repo, deploy key, filter config, mailmap, workflow, read-only enforcement).
---

You are running the `/repo-public-mirror-setup` skill. Your job is to
bootstrap a filtered, read-only public mirror for the **current
private repo** (the repo `cd`-ed into when this skill was invoked).
The setup is multi-step and partly destructive: it creates a new
public GitHub repo, uploads a deploy key, and stores a repo secret.
It also writes (but does not commit) filter config and a workflow
file in the source repo.

The first instance of this pattern is issue #26 in
`TheVoskamps/macos-setup-global-claude` (creating
`TheVoskamps/macos-setup-global-claude-public`). This skill codifies
that pattern so it can be applied to other private repos without
re-deriving the plumbing each time.

Follow the steps below in order. There are three explicit **halts**
where you wait for the user before proceeding. Do not skip them.

---

## Inputs

- **SSH key path** (required): path to the keypair the user
  generated out-of-band with `ssh-keygen`. The agent cannot
  generate SSH keypairs (blocked by `settings.json`), so the user
  must produce the key first and pass the path in.

  If the user did not provide a path when invoking the skill, ask
  for one before doing anything else. The path may be absolute
  (`/Users/<name>/.ssh/<repo>-mirror`) or `~`-prefixed; expand `~`
  to the user's home directory before checking the filesystem.

Everything else is derived by convention (see Step 4).

---

## Step 1: Pre-flight — repo root and visibility

Verify you are inside a git working tree:

```bash
git rev-parse --show-toplevel
```

Treat the path printed by this command as the **repo root** for the
rest of the skill. The skill operates on the source repo (the repo
the user invoked it from), not on `~/.claude`. Do **not** assume
`~/.claude` or any other path.

If the command fails (non-zero exit, "not a git repository"), abort
with:

> `/repo-public-mirror-setup` must be run from inside a git
> repository. The current directory is not a git working tree.

Then verify the source repo is **private**:

```bash
gh repo view --json visibility -q .visibility
```

If the value is anything other than `PRIVATE`, abort with:

> `/repo-public-mirror-setup` is only valid for private source
> repos. The current repo's visibility is `<value>`. A public repo
> doesn't need a filtered public mirror; if you want a different
> kind of mirror, that's out of scope for this skill.

## Step 2: Pre-flight — SSH key path

Resolve `~` in the SSH key path the user gave you, then verify both
halves exist:

- `<path>` (private half) must exist and be a regular file.
- `<path>.pub` (public half) must exist and be a regular file.

If either is missing, abort with a message naming the exact path
that was missing and reminding the user to generate the keypair
with `ssh-keygen`. Use the same `<short>-public` suffix as the
mirror repo so the key→repo mapping is obvious (e.g.
`ssh-keygen -t ed25519 -C '<short>-public'
-f ~/.ssh/<short>-public`). Do not offer to generate the key
yourself — key generation is out of scope and blocked by
`settings.json`.

Do **not** print the private key contents to the conversation at
any point in this skill. Pass it to `gh secret set` via stdin, not
via a shell argument.

## Step 3: Pre-flight — local tooling

Verify `git-filter-repo` is installed locally:

```bash
command -v git-filter-repo
```

If it returns nothing (exit non-zero), abort with:

> `git-filter-repo` is not installed. Install it with
> `brew install git-filter-repo`, then re-run
> `/repo-public-mirror-setup`.

Also verify `gh` is authenticated and has scope to create
repositories under the target org. A quick smoke test:

```bash
gh auth status
```

If `gh` reports the user is not authenticated, abort and instruct
them to run `gh auth login` (with `repo` scope, plus
`admin:public_key` so the deploy-key step in Step 15 works).

## Step 4: Derive names and identifiers

From the source repo, derive the conventional names:

- **Source repo full name**: read with
  `gh repo view --json nameWithOwner -q .nameWithOwner` (e.g.
  `TheVoskamps/macos-setup-global-claude`).
- **Source repo short name**: the part after the slash (e.g.
  `macos-setup-global-claude`).
- **Mirror repo full name**: `<owner>/<short>-public`.
- **Mailmap domain**: `<short>.local` (the `.local` TLD is
  RFC-reserved and non-routable; embedding the source short name
  makes the mirror's origin obvious to anyone reading the
  rewritten emails).
- **Secret name on source repo**: `PUBLIC_MIRROR_DEPLOY_KEY`
  (constant; not per-repo).
- **Deploy-key title on mirror repo**: `public-mirror-workflow`
  (constant).

## Step 5: Halt #1 — confirm derived values

Present the derived values to the user and ask for explicit
confirmation before doing anything that touches the filesystem or
GitHub. Use this exact shape:

```text
About to set up a public mirror with the following derived values:

  Source repo:    <owner>/<short>
  Mirror repo:    <owner>/<short>-public        (will be CREATED public)
  Mailmap domain: <short>.local
  Source secret:  PUBLIC_MIRROR_DEPLOY_KEY      (will be SET on source)
  Deploy key:     public-mirror-workflow        (will be UPLOADED to mirror)
  SSH key path:   <expanded-path>

Proceed? (y to continue, or tell me what to change)
```

Wait for explicit approval (`y`, `yes`, `go`, `do it`). If the user
asks for a different mirror name, mailmap domain, or secret name,
update the derived values and re-display this halt — do not
proceed without confirmation.

The remaining steps perform real work. Do not skip this halt.

## Step 6: Write `.github/public-mirror/` config in the source repo

Create the directory `<repo-root>/.github/public-mirror/` if it
does not exist, then write the three files below. These files are
**not** committed by the skill — the user reviews the diff and
commits manually, per global rule §0 ("never write/commit without
approval").

### `paths.allowlist`

Newline-delimited path patterns passed to
`git-filter-repo --paths-from-file`. Pre-list the required-files
starting set (the user fills in the rest in Halt #2):

```text
# Allowlist for the public mirror.
#
# Lines starting with `#` and blank lines are ignored. Every other
# line is a path or path prefix passed to `git-filter-repo
# --paths-from-file`. Anything not matched is excluded from the
# mirror (fail-safe for new sensitive files).
#
# The starting set below contains the files this skill requires to
# be present in the mirror. Add repo-specific paths below the
# marker. Audit additions carefully — paths NOT on this list are
# excluded, but paths that ARE on this list ship verbatim.

# --- required (do not remove) ---
README.md
LICENSE
PATENTS
PRIOR_ART.md
CODEOWNERS
.gitignore
.github/public-mirror/
.github/workflows/public-mirror.yml
pull_request_template.md

# --- repo-specific (add below) ---
```

### `mailmap`

Seed from the source repo's unique authors. Run:

```bash
git log --format='%aN <%aE>' | sort -u
```

For each unique `Name <local@domain>` line, emit a mailmap entry
that preserves the localpart and rewrites the domain to
`<short>.local`:

```text
<Name> <local@<short>.local> <local@<original-domain>>
```

Prepend a comment header:

```text
# Per-author mailmap used by the public-mirror workflow.
#
# Each line maps a private email to a `<localpart>@<short>.local`
# form. The `.local` TLD is RFC-reserved and non-routable, and
# embedding the source repo short name makes the mirror's origin
# obvious. `git-filter-repo --mailmap` rewrites author/committer
# emails on every filtered commit.
#
# Add a new entry here when a new author appears in the source repo.
```

If `git log` returns zero authors (empty repo), still write the
header so the file exists. Do not invent entries.

### `CONTRIBUTORS.template`

Write the header that the workflow concatenates with the
regenerated `git shortlog -sne` body each run. Embed the literal
source short name in the upstream URL placeholder so the message
makes sense in the mirror:

```text
# Contributors

This file is part of a **read-only public mirror**. All commits
originate upstream in the private source repository. Contributions
are not accepted in this mirror — see the upstream repo for the
contribution process.

The list below is regenerated on every workflow run from filtered
`git shortlog -sne` against the rewritten history, so emails are
in the `<localpart>@<short>.local` form.

---
```

Replace `<short>` with the actual source short name when writing.

## Step 7: Write `.github/workflows/public-mirror.yml`

Create the workflow file. It triggers on `push` to `main` and on
`workflow_dispatch` for manual reruns. Steps: checkout full
history, install `git-filter-repo`, clone a fresh bare copy, run
the filter with `--paths-from-file` and `--mailmap`, regenerate
`CONTRIBUTORS`, force-push to the mirror's `main`.

Use this template, substituting `<owner>/<short>-public` for the
mirror's full name:

```yaml
name: public-mirror

on:
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: public-mirror
  cancel-in-progress: false

jobs:
  mirror:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source (full history)
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Install git-filter-repo
        run: |
          python3 -m pip install --user git-filter-repo
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"

      - name: Set up SSH deploy key
        env:
          DEPLOY_KEY: ${{ secrets.PUBLIC_MIRROR_DEPLOY_KEY }}
        run: |
          mkdir -p ~/.ssh
          chmod 700 ~/.ssh
          printf '%s\n' "$DEPLOY_KEY" > ~/.ssh/id_mirror
          chmod 600 ~/.ssh/id_mirror
          # NOTE: ssh-keyscan is TOFU (Trust-On-First-Use) — the very
          # first run trusts whatever key the GitHub IP returns. The
          # GitHub-hosted runner is reaching GitHub from inside the
          # same provider's network on every run, so the practical
          # attack surface is narrow, but pinning is stronger. If
          # this workflow is ever ported off GitHub-hosted runners,
          # replace this line with pinned host keys fetched from
          # https://api.github.com/meta (the `ssh_keys` field, with
          # the connection itself trusted via TLS PKI).
          ssh-keyscan github.com >> ~/.ssh/known_hosts
          cat >> ~/.ssh/config <<EOF
          Host github-mirror
            HostName github.com
            User git
            IdentityFile ~/.ssh/id_mirror
            IdentitiesOnly yes
          EOF

      - name: Filter into a fresh bare clone
        env:
          CONF: ${{ github.workspace }}/.github/public-mirror
        run: |
          set -euo pipefail
          WORK=$(mktemp -d)
          git clone --bare . "$WORK/src.git"
          cd "$WORK/src.git"
          git filter-repo \
            --paths-from-file "$CONF/paths.allowlist" \
            --mailmap "$CONF/mailmap"
          echo "FILTERED=$WORK/src.git" >> "$GITHUB_ENV"

      - name: Regenerate CONTRIBUTORS
        env:
          CONF: ${{ github.workspace }}/.github/public-mirror
          BOT_EMAIL: public-mirror@<short>.local
        run: |
          set -euo pipefail
          cd "$FILTERED"
          # Build the new file content in $RUNNER_TEMP (the bare clone
          # has no working tree to write into), then insert it as a
          # blob and synthesize a new tree that adds the CONTRIBUTORS
          # entry on top of HEAD's existing tree.
          {
            cat "$CONF/CONTRIBUTORS.template"
            echo
            git shortlog -sne --all
          } > "${RUNNER_TEMP}/CONTRIBUTORS"
          BLOB=$(git hash-object -w "${RUNNER_TEMP}/CONTRIBUTORS")
          # Short-circuit: if the freshly-generated CONTRIBUTORS blob
          # is byte-identical to the one already at HEAD:CONTRIBUTORS,
          # do not synthesize a new commit. Skipping the commit here
          # keeps refs/heads/main pointing at the filter-repo output,
          # so a no-source-change run produces a tip SHA identical to
          # the previous run's tip and the force-push downstream
          # becomes a no-op.
          HEAD_BLOB=$(git rev-parse --verify --quiet HEAD:CONTRIBUTORS || true)
          if [ -n "$HEAD_BLOB" ] && [ "$BLOB" = "$HEAD_BLOB" ]; then
            echo "CONTRIBUTORS unchanged (blob $BLOB); skipping synthetic commit."
            exit 0
          fi
          # Reuse HEAD's tree as the base, then overlay the new blob
          # via a temporary index. read-tree loads HEAD's tree into
          # the index; update-index --add registers the new blob;
          # write-tree emits the resulting tree SHA.
          export GIT_INDEX_FILE="${RUNNER_TEMP}/idx"
          rm -f "$GIT_INDEX_FILE"
          git read-tree HEAD
          git update-index --add --cacheinfo "100644,$BLOB,CONTRIBUTORS"
          NEW_TREE=$(git write-tree)
          unset GIT_INDEX_FILE
          # Pin author/committer dates to HEAD's committer date so the
          # synthetic commit's SHA is deterministic across runs. Using
          # wall-clock here would change the tip SHA on every run even
          # when nothing else changed, which is the root cause of the
          # spurious force-pushes consumers see.
          HEAD_DATE=$(git show -s --format=%cI HEAD)
          NEW_HEAD=$(GIT_AUTHOR_DATE="$HEAD_DATE" \
                     GIT_COMMITTER_DATE="$HEAD_DATE" \
                     git -c user.name='public-mirror' \
                         -c user.email="$BOT_EMAIL" \
                       commit-tree "$NEW_TREE" -p HEAD \
                       -m 'Regenerate CONTRIBUTORS')
          git update-ref refs/heads/main "$NEW_HEAD"

      - name: Force-push to mirror
        run: |
          set -euo pipefail
          cd "$FILTERED"
          git remote add mirror git@github-mirror:<owner>/<short>-public.git
          # Defense-in-depth: if the mirror's current refs/heads/main
          # already matches our new tip, do not push. This catches
          # any case the CONTRIBUTORS short-circuit above misses (and
          # keeps no-op runs from moving the remote tip even if the
          # filter output is identical for some other reason).
          LOCAL_TIP=$(git rev-parse refs/heads/main)
          REMOTE_TIP=$(git ls-remote mirror refs/heads/main | awk '{print $1}')
          if [ -n "$REMOTE_TIP" ] && [ "$LOCAL_TIP" = "$REMOTE_TIP" ]; then
            echo "Mirror refs/heads/main already at $LOCAL_TIP; nothing to push."
            exit 0
          fi
          git push --force mirror refs/heads/main:refs/heads/main
```

Notes on the template:

- The `Regenerate CONTRIBUTORS` step works against a **bare clone**
  (no working tree), so it cannot just `git add CONTRIBUTORS &&
  git commit`. Instead it inserts the new file content as a blob
  with `git hash-object -w`, overlays that blob onto HEAD's tree
  via a temporary index (`GIT_INDEX_FILE` pointed at
  `${RUNNER_TEMP}/idx`, `read-tree` + `update-index --cacheinfo` +
  `write-tree`), and then uses `commit-tree` to wrap the new tree
  in a single synthetic commit on top of the filtered history.
  The synthetic commit doesn't dirty any of the rewritten commits'
  SHAs upstream of it.
- All temporary files live under `${RUNNER_TEMP}` (the
  GitHub-recommended runner temp dir), not `/tmp/`.
- Replace `<short>` in the `user.email` and `<owner>/<short>-public`
  in the remote URL with real values when writing the file.
- `concurrency: public-mirror` prevents overlapping force-pushes if
  two pushes land on `main` close together.
- The `Regenerate CONTRIBUTORS` step pins `GIT_AUTHOR_DATE` and
  `GIT_COMMITTER_DATE` to HEAD's committer date before
  `commit-tree`, so the synthetic commit's SHA is derived
  deterministically from upstream rather than from wall-clock. It
  also short-circuits when the freshly-generated `CONTRIBUTORS`
  blob already equals the one at `HEAD:CONTRIBUTORS`, leaving
  `refs/heads/main` at the filter-repo output unchanged.
- The `Force-push to mirror` step compares the new local tip to the
  mirror's current `refs/heads/main` (`git ls-remote`) and exits
  without pushing when they match. This is defense in depth on top
  of the CONTRIBUTORS short-circuit — together they ensure a
  no-source-change workflow run does not move the mirror's tip,
  which is what lets consumers do a normal `git pull` instead of
  `git fetch && git reset --hard`. Note this only stabilises SHAs
  across no-op runs; genuine upstream changes still cause
  `git filter-repo` to re-derive descendant SHAs and force-push,
  which is tracked separately (see issue #122).

## Step 8: Halt #2 — user populates `paths.allowlist`

Tell the user that the three config files and the workflow now
exist on disk (uncommitted), and that the **allowlist's
repo-specific section is empty**. The mirror will be nearly empty
on first run if the user does not add paths.

Suggest a starting place: re-read the source repo's `.gitignore`
(if it uses a whitelist style) or list the top-level entries with
`ls -A` so the user can decide which directories belong in the
mirror. Then ask:

> Edit `.github/public-mirror/paths.allowlist` now, adding any
> repo-specific paths under the `--- repo-specific (add below) ---`
> marker. Tell me when you're done.

Wait for explicit confirmation that the file is ready. Do not
advance to Step 9 until the user says so.

## Step 9: Dry-run the filter locally

In a sandbox directory under `.claude/tmp/repo-public-mirror-setup/`
(per the `<repo-root>/.claude/tmp/` convention — never `/tmp/`),
run the filter against a fresh bare clone of the source repo.
Print the resulting tree so the user can see exactly what would
land in the mirror.

```bash
# Capture the absolute repo root BEFORE cd-ing, so the filter
# config paths resolve correctly regardless of cwd depth.
REPO_ROOT="$(git rev-parse --show-toplevel)"
mkdir -p "$REPO_ROOT/.claude/tmp/repo-public-mirror-setup"
WORK="$REPO_ROOT/.claude/tmp/repo-public-mirror-setup/dryrun"
rm -rf "$WORK"
git clone --bare "$REPO_ROOT" "$WORK"
( cd "$WORK" \
  && git filter-repo \
       --paths-from-file "$REPO_ROOT/.github/public-mirror/paths.allowlist" \
       --mailmap "$REPO_ROOT/.github/public-mirror/mailmap" \
  && git ls-tree -r --name-only HEAD | sort )
```

Print the sorted list of file paths from `git ls-tree -r
--name-only HEAD`. Group it by top-level directory for legibility
if the list is long.

If `tree` is installed, an alternative second display is helpful:

```bash
( cd "$WORK" \
  && git archive --format=tar HEAD | tar -tf - | sort \
       | sed 's#[^/]##g;s#/#  #g' )
```

Either form is fine — the point is the user can audit the contents
before any remote push.

Cleanup of the sandbox is deferred to after Step 16 succeeds, so
the user can re-run the listing if they want.

## Step 10: Halt #3 — user confirms the dry-run tree

Ask explicitly:

> Does this look right? Check for two things:
>
> 1. No leaked sensitive paths (anything you don't want published).
> 2. All expected paths present (every file the mirror needs).
>
> Reply `y` to proceed with creating the mirror repo, or tell me
> what to change in the allowlist.

Wait for explicit `y`/`yes`/`go`. If the user asks for changes,
loop back to Step 8 — they edit the allowlist, you re-run the
dry-run, you re-display the tree, you ask again.

After this halt the skill proceeds through repo creation, deploy
key, and secret upload **without further halts** — those are the
plumbing steps that are safe once the tree has been approved.

## Step 11: Create the mirror repo

```bash
DESC="Read-only public mirror of <owner>/<short> (private)."
gh repo create <owner>/<short>-public \
  --public \
  --description "$DESC See upstream." \
  --disable-issues \
  --disable-wiki
```

`--disable-issues` and `--disable-wiki` are passed at creation
time. `gh repo create` does not have a `--disable-discussions`
flag, so Discussions are handled in Step 13.

If the repo already exists, abort with a clear message rather than
overwriting. This skill is for green-field setup — migration of an
existing public mirror to this pattern is out of scope.

## Step 12: Push the initial commit to establish `main`

Create the bootstrap content locally in
`.claude/tmp/repo-public-mirror-setup/bootstrap/` and push it as
the first commit on the mirror's `main`. This establishes `main`
so branch protection in Step 14 can apply. The workflow will
overwrite this commit's history on the first real filter run; the
purpose here is purely to create a default branch.

Files in the bootstrap commit:

- `README.md` — read-only banner with upstream link.
- `pull_request_template.md` — redirects contributions upstream.
- Copies of `LICENSE`, `PATENTS`, `PRIOR_ART.md`, `CODEOWNERS`,
  `.gitignore` from the source repo, if they exist. If any of these
  do not exist in the source, skip them silently — the workflow
  will only ever publish what's in the source repo anyway.

### `README.md` bootstrap content

```markdown
# <short> (public mirror)

> **Read-only mirror.** This repository is generated automatically
> from the private upstream. All commits originate there. Do not
> open issues or pull requests here — see the upstream repo for the
> contribution process.

Upstream: `<owner>/<short>` (private; access on request).
```

### `pull_request_template.md` bootstrap content

```markdown
This repository is a **read-only public mirror**. Pull requests are
not accepted here.

Please close this PR and open your change against the upstream
private repository instead. The upstream maintainers can grant
access if you need it.
```

Push sequence (run from the source repo root):

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
BOOT="$REPO_ROOT/.claude/tmp/repo-public-mirror-setup/bootstrap"
mkdir -p "$BOOT"
cd "$BOOT"
git init -b main
```

Then populate the bootstrap directory as explicit, separate
actions (do not bundle into a comment):

1. Write `README.md` with the bootstrap content shown above.
2. Write `pull_request_template.md` with the bootstrap content
   shown above.
3. For each of `LICENSE`, `PATENTS`, `PRIOR_ART.md`, `CODEOWNERS`,
   `.gitignore`: if the file exists at `$REPO_ROOT/<name>`, copy
   it to `$BOOT/<name>`. Skip silently if the source file does
   not exist.

Then commit and push:

```bash
git add .
git -c user.name='public-mirror-setup' \
    -c user.email='public-mirror-setup@<short>.local' \
    commit -m 'Bootstrap mirror; real history follows from workflow'
git remote add origin git@github.com:<owner>/<short>-public.git
git push -u origin main
```

This commit will be replaced on the first real workflow run. Its
only purpose is to give `main` a SHA so branch protection can
attach to it.

## Step 13: Disable Issues and Discussions on the mirror

```bash
gh repo edit <owner>/<short>-public \
  --enable-issues=false \
  --enable-discussions=false \
  --enable-wiki=false \
  --enable-projects=false
```

`--enable-issues=false` is redundant with the `--disable-issues`
passed at create time, but stating it here keeps the intent
explicit and makes this step self-contained if re-run.

## Step 14: Apply branch protection on the mirror's `main`

In practice, the deploy key uploaded in Step 15 is the only
**non-admin** identity with write access to an otherwise-empty
repo, so day-to-day writes come exclusively from the workflow.
Repo admins (and org admins) still retain push access regardless
of this protection — branch protection on GitHub does not lock
admins out unless `enforce_admins` is set, and that flag is
intentionally left off here so a human can intervene if the
workflow gets stuck. Use `gh api` because `gh repo edit` does not
cover branch protection rules.

```bash
gh api \
  --method PUT \
  -H 'Accept: application/vnd.github+json' \
  /repos/<owner>/<short>-public/branches/main/protection \
  --input - <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": true,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": false,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON
```

Notes:

- `allow_force_pushes: true` is intentional — the workflow
  force-pushes filtered history on every run.
- `restrictions: null` means GitHub uses repository-level push
  permissions. Because the deploy key is the only **non-admin**
  identity with write access (the repo is otherwise empty of
  collaborators), the practical effect is that day-to-day writes
  come from the workflow. Repo and org admins retain push access;
  if you need to lock them out, you'd set `enforce_admins: true`
  — left off here so a human can intervene if the workflow gets
  stuck.
- If the target org enforces stricter protection rules via
  rulesets, this PUT may be rejected. In that case surface the
  error to the user and stop — the user resolves the conflict at
  the org level, then asks the skill to retry.

## Step 15: Upload the public half as a deploy key on the mirror

```bash
gh repo deploy-key add <expanded-path>.pub \
  --repo <owner>/<short>-public \
  --title public-mirror-workflow \
  --allow-write
```

`--allow-write` is required because the workflow force-pushes to
the mirror.

## Step 16: Store the private half as a secret on the source repo

Read the private-key file and pipe it to `gh secret set`. Do not
expand the contents into the conversation or into shell argv.

```bash
gh secret set PUBLIC_MIRROR_DEPLOY_KEY \
  --repo <owner>/<short> \
  < "<expanded-path>"
```

The redirect target is quoted so paths containing spaces (e.g.
`/Users/Alice Smith/.ssh/repo-mirror`) work correctly.

The secret name `PUBLIC_MIRROR_DEPLOY_KEY` matches the
`${{ secrets.PUBLIC_MIRROR_DEPLOY_KEY }}` reference in the
workflow written in Step 7.

## Step 17: Print the next-steps checklist

Print this checklist to the user. The skill does **not** commit
the source-repo files — the user reviews and commits manually
(global rule §0).

```text
Public mirror bootstrap complete.

Created on GitHub:
  - <owner>/<short>-public (public, Issues/Discussions off)
  - Branch protection on main (force-push allowed for workflow only)
  - Deploy key: public-mirror-workflow (write-enabled)
  - Source secret: PUBLIC_MIRROR_DEPLOY_KEY

Uncommitted in this repo (review and commit when ready):
  - .github/public-mirror/paths.allowlist
  - .github/public-mirror/mailmap
  - .github/public-mirror/CONTRIBUTORS.template
  - .github/workflows/public-mirror.yml

Next steps:
  1. Review the diff:    git diff --stat .github/
  2. Commit and push:    triggers the first real workflow run.
  3. Watch the run:      gh run watch (on push to main)
  4. Verify the mirror:  the contents on
     <owner>/<short>-public should match the dry-run tree.

If the first real workflow run fails, common causes:
  - paths.allowlist references a path that doesn't exist in
    history (filter-repo treats this as fatal — fix the path
    or drop the entry)
  - mailmap has malformed entries (filter-repo logs the bad line)
  - deploy key lacks write scope (re-run gh repo deploy-key add
    with --allow-write)
```

Then clean up the sandbox if the run succeeded:

```bash
rm -rf .claude/tmp/repo-public-mirror-setup
```

Leave the sandbox in place if any step from 11 onward failed, so
the user can inspect it.

---

## Halts and approval gates (summary)

The skill **must** halt and wait for explicit user confirmation at:

- **Halt #1 (Step 5)** — derived values (mirror name, mailmap
  domain, secret name, deploy-key title).
- **Halt #2 (Step 8)** — user populates `paths.allowlist` with
  repo-specific paths.
- **Halt #3 (Step 10)** — dry-run tree review before any
  destructive remote action.

After Halt #3, Steps 11–16 run without further halts — those are
the plumbing steps that are safe once the tree has been approved.

---

## Hard constraints

- **Never run before all pre-flight checks (Steps 1–3) pass.**
  Each abort message must name the exact thing that failed and
  what the user should do about it.
- **Never write or commit the source-repo files for the user.**
  Step 6 and Step 7 create the files on disk uncommitted; the user
  reviews the diff and commits manually. (Global rule §0: never
  commit without approval.)
- **Never edit anything outside the source repo.** The skill
  writes files under `<repo-root>/.github/public-mirror/`,
  `<repo-root>/.github/workflows/`, and
  `<repo-root>/.claude/tmp/repo-public-mirror-setup/`. Nothing
  outside the source repo gets touched on disk; the only remote
  changes are on the newly-created mirror and the
  `PUBLIC_MIRROR_DEPLOY_KEY` secret on the source.
- **Never skip a halt.** All three halts (Steps 5, 8, 10) are
  required. A "looks fine, proceeding" response without explicit
  user confirmation is not approval.
- **Never print private key material to the conversation.** Pipe
  the private key file directly into `gh secret set` via stdin.
  The `gh secret set ... < <path>` form is required.
- **Never run on a public source repo.** Step 1 aborts if the
  source visibility is anything other than `PRIVATE`.
- **Never proceed if `git-filter-repo` is missing.** Step 3 aborts
  with the install command. Do not attempt to install it yourself
  — the user runs `brew install git-filter-repo`.
- **All scratch work done by the skill on the user's machine goes
  under `.claude/tmp/...`** in the source repo, never `/tmp/`,
  never the user's home directory, never a path outside the repo.
  Clean up on success; leave in place on failure. (This constraint
  applies to the **skill**. The generated workflow runs on
  GitHub-hosted Actions runners, a separate execution context with
  its own conventions — there it uses `${RUNNER_TEMP}`, the
  GitHub-recommended runner temp dir, not the repo tree.)
- **Use `gh repo create --disable-issues --disable-wiki` at
  creation time**, then a follow-up `gh repo edit
  --enable-discussions=false` (Step 13) because `gh repo create`
  does not expose a `--disable-discussions` flag.

---

## Out of scope

- **SSH keypair generation.** Blocked by `settings.json`. The user
  generates the key out-of-band and passes the path in.
- **The first real filtered push.** The skill establishes `main`
  with a bootstrap commit (Step 12) so branch protection can
  apply, but the first filtered history push only happens when the
  user commits the source-repo files (Steps 6–7) and pushes,
  triggering the workflow.
- **Repo-specific allowlist contents** beyond the required-files
  starting set. The user fills these in at Halt #2.
- **Migration of an existing public mirror to this pattern.** This
  skill is for green-field setup only. If `<owner>/<short>-public`
  already exists, Step 11 aborts.
- **Auditing the contents of the source repo for sensitive data
  before publishing.** The allowlist-only filter is fail-safe for
  *new* files added later, but the user is responsible for
  reviewing the dry-run tree at Halt #3 to confirm nothing
  currently in history leaks.
