# Dependency Discipline (Subagents)

Subagents must not improvise dependency installs to "fix" a missing
tool. The only install command a subagent may run on its own
initiative is the project's **deterministic-from-lockfile install**.
For Node that is `npm ci`. For Python that is
`pip install -r requirements.txt --no-deps` inside an active venv (or
the equivalent for `uv`, `poetry`, `pipenv`). For other languages,
the analogous lockfile-honoring install (`pnpm install --frozen-lockfile`,
`yarn install --frozen-lockfile`, `cargo build` with a committed
`Cargo.lock`, `go build` with a committed `go.sum`, etc.).

A deterministic install reads exactly what the project's lockfile
declares. No version drift, no edits to `package.json` or
`requirements.txt`, no lockfile churn, fully reproducible.

## Forbidden install patterns

The following are forbidden as on-own-initiative recovery in a
subagent, even when a tool is missing and an install "obviously"
would fix it:

- `npm install <pkg>` / `npm i <pkg>` — writes to `package.json`
  and `package-lock.json`, resolves an undeclared version, drifts
  the worktree from the PR's actual state, may trigger `preinstall`
  hooks that cascade installs elsewhere.
- `npm install -g <pkg>`, `pnpm add -g <pkg>`, `yarn global add <pkg>`
  — host pollution (also forbidden by
  `rules/forbid-host-modifications.md`).
- `pip install <pkg>` outside a venv with a pinned
  `requirements.txt` (or equivalent), `pip install --user`,
  `pipx install`, `uv pip install` outside a venv.
- `brew install`, `brew upgrade`, `mas install`.
- `gem install` (with or without `--user-install`).
- `cargo install`, `go install`.
- Adding to `node_modules/`, `site-packages/`, or any project
  dependency tree by other means — downloading binaries with `curl`
  or `wget`, extracting tarballs with `tar -xf`, copying wheels in
  by hand, etc.

This list is illustrative, not exhaustive. The principle: a subagent
must not resolve an undeclared version or write outside what the
project's lockfile already authorizes.

## When a deterministic install is not enough

If `npm ci` (or the language equivalent) does not give you the tool
you need, **stop and escalate**. Do not improvise. The escalation
message names:

1. **Which tool is missing** (`cdk`, `tsc`, `kubectl`, etc.).
2. **Which command failed** and the project's declared way to
   invoke that tool (`npm run synth`, `npx tsc`, `npm test`, etc.).
   Quote the verbatim error output; do not paraphrase.
3. **The shortest explanation** of why this isn't something the
   subagent can fix in scope. Example:

   > The project's `npm run synth` script invokes bare `cdk`; the
   > `node_modules/.bin/cdk` is installed by `npm ci` but isn't on
   > PATH for the script's subshell. The repo-side fix is to change
   > the script to `npx cdk synth` (tracked in issue #1058). I'm
   > escalating because `npm install aws-cdk` would drift the
   > project's declared deps, and `npm install -g aws-cdk` is
   > forbidden by `rules/forbid-host-modifications.md`.

The orchestrator's job, on receiving the escalation, is to surface
it to the human verbatim. The human's options are:

- (a) Fix the project (e.g. land the repo-side script fix).
- (b) Explicitly approve an ad-hoc install for this one task. That
  approval does NOT carry over to the next task or the next tool;
  each ad-hoc install requires its own approval.
- (c) Abandon the task.

## What this rule does NOT forbid

- `npm ci`, `pnpm install --frozen-lockfile`,
  `yarn install --frozen-lockfile` — these install only what the
  lockfile declares and are the canonical path.
- `pip install -r requirements.txt` inside an active venv when the
  requirements file is part of the project. Same idea: install only
  what the project declares.
- `npx <tool>` invocations that resolve from the project's
  `node_modules/.bin` after a clean `npm ci`. These don't install
  anything new; they run what the lockfile already brought in.
- Running already-installed tooling. Detecting "tool X is missing"
  is fine; deciding to install it on the subagent's own initiative
  is not.

## Relationship to other rules

- `rules/forbid-host-modifications.md` forbids host-affecting
  recovery (e.g. `npm install -g`, `brew install`) for **both** the
  main session and subagents. Its "What this rule does NOT forbid"
  section explicitly permits `npm install` without `-g` because the
  main session legitimately runs that under user direction. This
  file (`dependency-discipline.md`) tightens that carve-out for
  subagents only: a subagent must not run `npm install <pkg>` even
  though the main session may.
- `rules/escalation-discipline.md` describes the general shape of
  "stop and report back" for environmental mismatches. The
  escalation flow in this file is a specialization of that pattern
  for the dependency-install case.
- `rules/credential-surfaces.md` covers credential-agent
  introspection, not dependency installs. The two files are
  parallel in style — "user-owned surfaces a subagent must not
  touch on its own initiative" — but they cover different surfaces.

## Why subagents specifically

The main session runs interactively with the user and can ask
before installing. Subagents run autonomously and the user only
sees their output after the fact. A `npm install aws-cdk` inside a
subagent commits the worktree to a version the project never
declared, and the user finds out when the PR diff includes
`package.json` and `package-lock.json` churn that has nothing to do
with the issue. By the time it's visible it's already done.

The asymmetry between this rule and the carve-out in
`forbid-host-modifications.md` is intentional: the main session
gets to run `npm install <pkg>` under user direction; subagents
don't, because there's no user to direct them in real time.

## Scope

Applies to all four subagents (`issue-developer`, `issue-fixer`,
`doc-updater`, `pr-reviewer`). The main session is bound by
`rules/forbid-host-modifications.md` (global installs are
forbidden) but is NOT bound by the additional non-global-install
restriction in this file — the main session may run
`npm install <pkg>` under user direction.

Subagents pick this rule up via the `~/.claude/CLAUDE.md` include
mechanism (see issue #68 and PR #71).
