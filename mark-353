# Forbid Host-Affecting Recovery

When a project-local command fails, **stop and report**. Do not
improvise a recovery that touches the user's global environment. The
user will decide whether to fix the repo (e.g. correct a bad script),
install something globally, or take a different path.

See also: `rules/core-principles.md` §0 ("NEVER EVER execute bash
commands that modify state without explicit approval"). This rule
extends that general principle by naming the specific class of
host-affecting recovery commands so it survives reasoning like "but
the build needs CDK, so installing CDK is implied."

## Forbidden commands

The following commands write outside the current repo/worktree and
must not be invoked on your own initiative:

- **Node**: `npm install -g`, `npm i -g`, `yarn global add`,
  `pnpm add -g`.
- **Python**: `pip install` outside the project's venv (where "in the
  venv" means either an activated venv OR an explicit invocation like
  `<venv>/bin/pip`, `uv run pip`, or `poetry run pip`);
  `pip install --user`; `pipx install`; `uv pip install` outside a
  venv.
- **macOS**: `brew install`, `brew upgrade`, `brew tap`,
  `brew uninstall`, `mas install`.
- **Ruby**: `gem install` without `--user-install`.
- **Rust / Go**: `cargo install`, `go install`.
- **Generic**: any package manager invocation that writes outside the
  current worktree.

This list is illustrative, not exhaustive. The principle is: anything
that modifies state outside the current worktree (the user's home
directory, their package managers, their PATH, their system
preferences) is forbidden as a recovery action.

## When a project-local command fails

1. **State the failure plainly.** Quote the verbatim error output;
   don't paraphrase.
2. **Identify the root cause** if it's evident from the error
   (e.g. "the `synth` script invokes bare `cdk` instead of `npx cdk`,
   which isn't on PATH").
3. **Report and stop.** Don't run a recovery. The user picks the fix.

This mirrors the existing escalation-discipline rule
(`~/.claude/rules/escalation-discipline.md`): an environmental mismatch
is a decision-point, not noise to silently solve.

## What this rule does NOT forbid

- Project-local installs (`npm install` without `-g`, `pip install` in
  an active venv, `cargo build`). These touch only the worktree.
  **Subagents are tightened further** by
  `rules/dependency-discipline.md`: a subagent may run `npm ci` (or
  the language-equivalent lockfile install) but may NOT run
  `npm install <pkg>` on its own initiative, because that writes to
  `package.json` / `package-lock.json` and resolves an undeclared
  version. The carve-out in this bullet applies to the main session
  under user direction.
- Tool invocations the user has explicitly approved for this exact
  command earlier in the same task. (Approval of `brew install foo`
  does NOT extend to `brew install bar` — each host-touching command
  requires its own approval.)
- Running already-installed tooling. Detecting "tool X is missing" is
  fine; deciding to install it on the user's behalf is not.

## Scope

Applies to the main session and to all four subagents
(`issue-developer`, `issue-fixer`, `doc-updater`, `pr-reviewer`).
Subagents pick this up automatically via the `~/.claude/CLAUDE.md`
include mechanism (see issue #68 and PR #71).
