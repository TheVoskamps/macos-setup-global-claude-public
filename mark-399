---
name: git-cleanup-branches-and-worktrees
description: Clean up merged local branches and remove stale subagent worktrees from `.claude/worktrees/`.
---

# git-cleanup-branches-and-worktrees

Please clean up merged local branches (regardless of naming convention)
and their worktrees, plus the throwaway worktrees that
`isolation: worktree` subagents leave behind.

## Long-lived branches (referenced from Steps 2, 5, and 9)

These branches are **never** deleted by this skill and are always
excluded from the merged-branch scan in Step 2. Step 5's orphan-
branch reachability check (Pass 2) uses them as the "fully landed"
yardstick. They are also the exact set Step 9 pulls forward at the
end of the run:

```text
main, integ, test, sbx-edwin
```

A repo that uses a different long-lived set must hand-edit **all
three locations**: the prose list above, the matching `grep -Ev`
regex in Step 2's bash snippet, **and** the
`^main ^integ ^test ^sbx-edwin` arguments in Step 5b's
`git rev-list` invocation. They must stay in sync, otherwise the
skill could silently delete a long-lived branch or skip an orphan
ref that is in fact fully landed.
Concretely: if a repo uses `develop` instead of `integ` and only
the prose list is updated, the regex still excludes `integ` (a
branch that doesn't exist here) while letting `develop` through
Step 2's enumeration as a deletion candidate. Steps 2, 5, and 9 all
refer back to this callout rather than repeating the names.

1. Run `git fetch --all --prune` to refresh tracking branches and
   remove stale remote refs.
2. List all local branches **except** the long-lived set above:

   ```bash
   git for-each-ref --format='%(refname:short)' refs/heads/ \
     | grep -Ev '^(main|integ|test|sbx-edwin)$'
   ```

   Filter out the long-lived set above. The remaining branches are
   candidates for the gate in Step 3 — this deliberately includes
   branches that don't match `issue-NNN-*` (e.g. `add-foo-skill`,
   `fix-bar-allowlist`, `update-settings-permissions`), because the
   gate (merged PR + remote gone) is the real safety signal, not the
   name pattern. Note: `worktree-*` branches that appear in this
   enumeration fail Step 3's gate (they have no merged PR) and are
   handled by Step 5 instead.
3. For each candidate branch, determine whether it is safe to delete.
   The check is **PR merged AND remote branch is gone** — both must hold.
   "Issue closed and assigned to me" is **not** a sufficient signal: an
   issue can be closed without its PR ever merging, and an unmerged
   branch may still hold work that hasn't landed on `main`.

   ```bash
   gh pr list --state merged --head <branch> --json number,mergedAt
   git ls-remote --exit-code origin <branch>   # exit 2 = branch is gone
   ```

   Both conditions must be true:
   - `gh pr list` returns a non-empty result for a merged PR on this branch
   - `git ls-remote --exit-code origin <branch>` exits 2 (branch absent on origin)

   A branch with no merged PR (e.g. a local-only branch you never
   pushed, or a remote-tracking branch for in-progress work) fails
   the gate and is left alone. The gate is the safety net; the
   broadened enumeration in Step 2 just stops the skill from
   ignoring merged branches that don't happen to start with
   `issue-`.

   **Note on the name-based PR match.** `gh pr list --head <branch>`
   matches by branch *name*, not by SHA. Edge case: a branch was deleted,
   then later recreated with the same name and a different commit lineage,
   and that new instance has its own merged PR. The name-based gate would
   pass even though the local SHA points at the *first* (now-gone) remote
   tip. The secondary safety check in step 4a handles this — the local
   branch's `@{upstream}` is gone in that scenario, so
   `git rev-list @{upstream}..HEAD` fails loudly and the worktree is
   skipped rather than silently removed.

   Closed-but-not-merged PRs are correctly excluded by `--state merged`.
   Force-pushed branches are also handled correctly: the gate requires
   the *branch* to be gone, not the local SHA to match the remote tip.

4. For branches where both conditions hold:
   a. Remove any git worktree under `.claude/worktrees/` that uses the
      branch. **Use plain `git worktree remove`, not `--force`** — the
      safety check matters; if it trips, we want to know.

      Before calling `git worktree remove <path>`, verify the worktree
      is in a known-safe state:
      - no uncommitted changes (`git status --porcelain` empty)
      - no unpushed commits relative to the branch's remote tracking
        ref (`git rev-list @{upstream}..HEAD` empty)

      If either check fails, **skip the worktree** and report the
      reason. Do not force-remove.

      If `git worktree remove` fails with `fatal: cannot remove a
      locked working tree`, inspect the lock reason via
      `git worktree list --porcelain`. If it matches the standard
      harness shape `claude agent agent-<hash> (pid NNNN)` AND the
      PID is no longer alive (`kill -0 <pid>` fails) OR the branch
      passed step 3's "merged + remote gone" gate (which is the case
      here, since we're inside step 4), this is a stale end-state
      lock from a returned or crashed subagent — run
      `git worktree unlock <path>` then re-run
      `git worktree remove <path>` (no `--force`). See
      `~/.claude/rules/worktree-cleanup.md`. If the lock reason does
      not match the harness shape, or the uncommitted/unpushed check
      above failed, skip and report — do not unlock and do not
      force-remove.
   b. Delete the local branch (`git branch -D`).
      (Safe because step 3 already confirmed the PR was merged AND the
      remote branch is gone; `git branch -d` gives false negatives when
      worktree checkouts are stale.)
   c. Delete the remote branch only if step 3's `git ls-remote` shows
      it still exists (defensive — usually it's already gone, which
      was part of the gate).

5. Clean up `isolation: worktree` subagent worktrees and their
   leftover branch refs. Claude Code's `isolation: worktree`
   produces branch names matching `worktree-*` (e.g.
   `worktree-agent-a39b0297dc3421b9e`).

   Enumerate candidates in two passes:

   a. **Pass 1 — worktrees that still exist.** List all worktrees
      under `.claude/worktrees/` whose checked-out branch matches
      `worktree-*`. For each, run the safety check:
      - no uncommitted changes
      - no unpushed commits relative to `@{upstream}` (the branch's
        own remote tracking ref). Do **not** compare against `main` —
        feature/worktree branches are expected to diverge from `main`;
        what matters is whether the branch is fully pushed to its own
        remote.

      If both checks pass: remove the worktree (`git worktree remove`,
      no `--force`) and delete the local branch (`git branch -d`).
      If either check fails: skip and report the reason.

      If `git worktree remove` fails with `fatal: cannot remove a
      locked working tree`, inspect the lock reason via
      `git worktree list --porcelain`. If the lock reason matches the
      standard harness shape `claude agent agent-<hash> (pid NNNN)`
      AND the PID in the lock reason is no longer alive
      (`kill -0 <pid>` fails — the harness exited uncleanly or the
      subagent has already returned), this is a stale end-state lock
      and the canonical cleanup is `git worktree unlock <path>`
      followed by `git worktree remove <path>` (no `--force`). See
      `~/.claude/rules/worktree-cleanup.md`. If the lock reason does
      not match the harness shape, or the PID is still alive (the
      subagent may be mid-run), **skip and report** — do not unlock
      a live subagent's worktree and do not force-remove. `--force`
      remains reserved for the data-loss carve-out (uncommitted work
      or unpushed commits the user has explicitly approved
      discarding), not for bypassing a lock.

   b. **Pass 2 — orphan branch refs with no worktree.** Some
      `worktree-*` branches are left behind as local refs after their
      worktree was already removed (the harness can leak these).
      Enumerate all local branches matching `worktree-*` that are
      **not** checked out in any worktree under `.claude/worktrees/`.
      For each, apply this decision tree:

      - **Branch has an upstream configured** (`git rev-parse
        --abbrev-ref --symbolic-full-name <branch>@{upstream}` succeeds
        and the upstream still exists on origin): use the same
        `@{upstream}..HEAD` empty check as Pass 1. If empty, delete the
        branch with `git branch -d`. If non-empty, skip and report
        (the branch holds unpushed work).
      - **Branch has no upstream configured, or the upstream is gone**
        (the harness creates these refs but never pushes them, so
        `@{upstream}..HEAD` fails loudly rather than giving a clean
        answer): fall back to a reachability check against the
        long-lived set defined at the top of this file. Concretely:

        ```bash
        git rev-list <branch> ^main ^integ ^test ^sbx-edwin --count
        ```

        If the count is `0`, every commit on `<branch>` is already
        reachable from at least one long-lived branch — the ref is
        a stale starting point with no unique history, so deleting it
        loses nothing. Delete with `git branch -D` (the `-D` form is
        required because the no-upstream state makes `git branch -d`
        refuse with "not fully merged" even though the commits are in
        fact reachable from a long-lived branch).

        If the count is non-zero, the branch has commits not on any
        long-lived branch — skip and report so the human can
        investigate before any history is dropped.

      If a repo uses a different long-lived set, the
      `^main ^integ ^test ^sbx-edwin` arguments above are one of the
      three locations that must be kept in sync — see the
      "Long-lived branches" callout at the top of this file.

6. Do **not** auto-clean nested worktrees
   (`.claude/worktrees/*/.claude/worktrees/`). If any are detected,
   report them with a note that nested worktrees indicate
   [Anthropic issue #47548](https://github.com/anthropics/claude-code/issues/47548)
   (`isolation: worktree` spawned from inside a worktree) and need
   human inspection. Auto-removing them risks data loss.
7. Run `git worktree prune` to clean up any stale worktree references.
8. Run `git fetch --all --prune` again to refresh tracking branches and
   remove stale remote refs.
9. For each long-lived branch in the set defined at the top of this
   file that exists in this repo:
   a. Check `git worktree list` first. If the target branch is
      currently checked out in another worktree (the harness sometimes
      keeps a worktree on `main`), do **not** `git switch` to it from
      the primary clone — git refuses to check out a branch claimed
      by another worktree. Instead, update the existing checkout in
      place: `git -C <that-path> pull --ff-only`.
      (Note: this `git -C` use is in *this script*, not in a subagent
      Bash call, so the subagent forbidden-form rule doesn't apply.)
   b. If the branch is **not** checked out elsewhere:
      - `git switch <branch-name>`
      - `git pull --ff-only`

10. Final summary — report counts:
    - Merged branches deleted (local + remote)
    - Subagent worktrees removed (Step 5a / Pass 1)
    - Orphan `worktree-*` branch refs deleted (Step 5b / Pass 2),
      broken down by which path applied (upstream-empty vs.
      no-upstream-reachable-from-long-lived-set)
    - Worktrees skipped, with reason for each (uncommitted changes,
      unpushed commits, nested worktree, etc.)
    - Orphan branch refs skipped, with reason for each (non-zero
      reachability count, etc.)
    - Default branches updated (which ones, which were updated in
      place via `git -C`)

    List anything that was skipped so the human can investigate.
