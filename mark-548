# Worktree Cleanup

Removing a locked worktree left behind by a returned `isolation:
worktree` subagent, by a crashed harness, or by a dead Claude agent
PID is **routine end-state cleanup**, not an escalation. The
canonical pattern is `git worktree unlock <path>` followed by
`git worktree remove <path>`. No human approval is required, and
`--force` is the wrong tool for this case.

`git worktree remove --force` (or `-f -f`) is reserved for the
genuine data-loss cases: a worktree with uncommitted changes the
user has chosen to discard, or a worktree whose branch has unpushed
commits the user has chosen to discard. Both still need approval
because they discard work — the approval is for the **data loss**,
not for the lock.

## Why this rule exists

Three workflows repeatedly tripped on the same false escalation:

- The `/issue-address` orchestrator hit `fatal: cannot remove a
  locked working tree` at end-of-wave on every subagent's worktree
  (the harness leaves a lock with reason `claude agent
  agent-<hash> (pid NNNN)` after the subagent detaches) and asked
  the user whether to force-remove.
- The `/git-cleanup-branches-and-worktrees` skill escalated on
  stale-locked worktrees whose harness PID was no longer alive.
- The main session, asked to clean up after a crashed harness,
  reached for `git worktree remove -f -f`.

The user's answer was the same every time: unlock-then-remove. The
"locked worktree" guard conflates two cases that need different
handling — "subagent has returned, lock is stale end-state" and
"subagent is doing something we shouldn't interrupt" — and the
destructive form (`-f`) is wrong even when the user does approve.

## What's allowed (no approval needed)

For a locked worktree whose lock reason matches the standard
harness shape `claude agent agent-<hash> (pid NNNN)`, AND **at
least one** of the following holds:

- The subagent that produced the worktree has already returned
  (i.e. the orchestrator received its final report and is now
  doing end-of-wave cleanup).
- The PID in the lock reason is no longer alive (`kill -0 <pid>`
  fails, or `ps -p <pid>` shows no process). This is the
  stale-lock case after a crashed harness.
- The worktree's branch is fully merged into the repo's default
  branch (verified the same way
  `/git-cleanup-branches-and-worktrees` does it — merged PR + remote
  branch gone, or `git rev-list <branch> ^<default-branch> --count`
  equals 0).

…then the canonical cleanup is:

```bash
git worktree unlock <path>
git worktree remove <path>
```

Plain `git worktree remove` (without `--force`) still enforces the
"no uncommitted changes, no unpushed commits" safety check on its
own. That is the right protection and stays. The unlock step
removes only the harness's end-state lock, not those safety
checks.

## What's forbidden (or requires approval)

- `git worktree remove --force` / `-f -f` against a locked
  worktree is the wrong tool for routine end-state cleanup. Use
  unlock-then-remove instead. `--force` is only appropriate when
  the worktree has uncommitted changes or unpushed commits AND the
  user has explicitly approved discarding that work — the approval
  is for the data loss, not for the lock.
- Removing a worktree whose subagent **has not yet returned**
  (still running, still in flight, or escalated mid-run). The
  subagent's lifecycle decision belongs to the human; do not
  unlock or remove on your own initiative.
- Removing a worktree whose lock reason **does not match** the
  standard harness shape (`claude agent agent-<hash> (pid NNNN)`).
  Some other tool or person locked it for reasons we don't
  understand; surface that to the human verbatim and wait for
  direction.
- Removing a worktree that contains **uncommitted work** or whose
  branch has **unpushed commits**. Plain `git worktree remove`
  already refuses this case — that refusal is the correct safety
  net. Skip the worktree and report the reason; do not reach for
  `--force` to bypass it.

## How to detect the cases

```bash
# Is the worktree locked, and with what reason?
git worktree list --porcelain
# Look for a "locked <reason>" line under the worktree's entry.

# Does the lock reason match the standard harness shape?
# Matches: "claude agent agent-<hash> (pid NNNN)"
# Concrete regex:
git worktree list --porcelain | \
  grep -E '^locked claude agent agent-[a-f0-9]+ \(pid [0-9]+\)$'

# Is the PID still alive?
kill -0 <pid> 2>/dev/null && echo "alive" || echo "dead"
# Edge case: on a multi-user host, `kill -0` can fail with EPERM
# when the PID exists but is owned by another user. The one-liner
# above treats EPERM as "dead", which is wrong in that case — the
# process is still running, just not ours to signal. On a
# single-user Mac this can't happen; if you ever run this tooling
# in a shared environment, distinguish EPERM (treat as "alive", do
# not unlock) from ESRCH (treat as "dead", safe to unlock).

# Does the worktree have uncommitted changes?
git -C <path> status --porcelain   # empty = clean
# (This `git -C` use is in cleanup tooling, not in a subagent Bash
# call — the subagent forbidden-form rule doesn't apply here.)

# Does the worktree's branch have unpushed commits?
git -C <path> rev-list @{upstream}..HEAD   # empty = fully pushed
# Note: `@{upstream}..HEAD` fails loudly with "no upstream
# configured" on branches that were never pushed — common for the
# harness's `worktree-agent-*` branches. Treat that failure as
# "not verifiable as pushed" and skip-and-report, OR fall back to
# a reachability check against the repo's default branch the way
# `/git-cleanup-branches-and-worktrees` Pass 2 does (see
# "Branch has no upstream configured, or the upstream is gone" in
# `skills/git-cleanup-branches-and-worktrees/SKILL.md`).
```

If the lock-reason check passes AND one of the three "subagent
returned / PID dead / branch fully merged" conditions holds AND
the worktree is clean and pushed, run unlock-then-remove without
asking. Otherwise, skip and report.

## Scope

Applies to the main session and to all four subagents
(`issue-developer`, `issue-fixer`, `doc-updater`, `pr-reviewer`).
Subagents pick this up automatically via the `~/.claude/CLAUDE.md`
include mechanism (see issue #68 and PR #71).
