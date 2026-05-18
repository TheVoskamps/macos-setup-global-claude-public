---
name: git-cleanup-branches-and-worktrees
description: Clean up merged local branches and remove stale subagent worktrees from `.claude/worktrees/`.
---

Please clean up merged local branches (regardless of naming convention)
and their worktrees, plus the throwaway worktrees that
`isolation: worktree` subagents leave behind.

### Long-lived branches (referenced from Steps 2 and 8)

These branches are **never** deleted by this skill and are always
excluded from the merged-branch scan in Step 2. They are also the
exact set Step 8 pulls forward at the end of the run:

```text
main, integ, test, sbx-edwin
```

A repo that uses a different long-lived set should hand-edit this
list (and the matching list in Step 8) before running the skill.

1. Run `git fetch --all --prune` to refresh tracking branches and remove stale remote refs.
2. List all local branches **except** the long-lived set above:

   ```bash
   git for-each-ref --format='%(refname:short)' refs/heads/
   ```

   Filter out `main`, `integ`, `test`, `sbx-edwin`. The remaining
   branches are candidates for the gate in Step 3 — this deliberately
   includes branches that don't match `issue-NNN-*` (e.g.
   `add-foo-skill`, `fix-bar-allowlist`, `update-settings-permissions`),
   because the gate (merged PR + remote gone) is the real safety
   signal, not the name pattern.
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
   b. Delete the local branch (`git branch -D`).
      (Safe because step 3 already confirmed the PR was merged AND the
      remote branch is gone; `git branch -d` gives false negatives when
      worktree checkouts are stale.)
   c. Delete the remote branch only if step 3's `git ls-remote` shows
      it still exists (defensive — usually it's already gone, which
      was part of the gate).

5. Clean up orphaned `isolation: worktree` subagent worktrees:
   a. List all worktrees under `.claude/worktrees/` matching the
      `worktree-*` branch pattern (Claude Code's `isolation: worktree`
      produces names like `worktree-bright-running-fox` — note the
      pattern is `worktree-*`, **not** `worktree-agent-*`; the older
      `agent-` prefix is gone).
   b. For each `worktree-*` worktree, run the safety check:
      - no uncommitted changes
      - no unpushed commits relative to `@{upstream}` (the branch's
        own remote tracking ref). Do **not** compare against `main` —
        feature/worktree branches are expected to diverge from `main`;
        what matters is whether the branch is fully pushed to its own
        remote.
      If both checks pass: remove the worktree (`git worktree remove`,
      no `--force`) and delete the local branch (`git branch -d`).
      If either check fails: skip and report the reason.

5a. Do **not** auto-clean nested worktrees
    (`.claude/worktrees/*/.claude/worktrees/`). If any are detected,
    report them with a note that nested worktrees indicate
    [Anthropic issue #47548](https://github.com/anthropics/claude-code/issues/47548)
    (`isolation: worktree` spawned from inside a worktree) and need
    human inspection. Auto-removing them risks data loss.

6. Run `git worktree prune` to clean up any stale worktree references.
7. Run `git fetch --all --prune` again to refresh tracking branches and
   remove stale remote refs.
8. For each long-lived branch in the set defined at the top of this
   file (`main`, `integ`, `test`, `sbx-edwin`) that exists in this
   repo:
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

9. Final summary — report counts:
   - Merged branches deleted (local + remote)
   - Subagent worktrees removed
   - Worktrees skipped, with reason for each (uncommitted changes,
     unpushed commits, nested worktree, etc.)
   - Default branches updated (which ones, which were updated in
     place via `git -C`)

   List anything that was skipped so the human can investigate.
