# Git Workflow

## Stay Within Your Repo

> **Scope note:** the rules in this top-level section apply to **both**
> the main session and Task-tool subagents — do not run outside the
> repo root in either context. The `cd` and command-form rules that
> follow split into two scoped subsections; **read the subsection that
> matches your context** ("Main session" or "Subagent context"). A
> subagent reading top-down should treat any unscoped advice in this
> section as the floor, not the ceiling — the subagent subsection
> further restricts what's allowed.

You should be run from the root of a repo. Verify with `git rev-parse
--show-toplevel` if unsure. If the starting CWD is not a repo root, tell
the user — don't guess.

In the **main session**, you may freely `cd` to any path **at or
below** the repo root, including:

- subdirectories of the repo
- worktrees under `.claude/worktrees/`
- back to the repo root

In a **subagent context** (`isolation: worktree`), the harness places
you in a worktree and `cd` does not persist between Bash calls — see
the "Subagent context" subsection for the working pattern.

You may **not** `cd` outside the repo root without permission, in
either context. If a fix requires changes in another repo, suggest the
change in the conversation; don't implement it.

The cwd rules below split into two scoped subsections: the **main
session** (this orchestrator process, direct human use) and
**subagent context** (Task-tool subagents declaring
`isolation: worktree` in their frontmatter). The two contexts behave
differently and require different command forms.

## Main session: cwd persists across Bash calls

This subsection applies to the **main session only** — the
orchestrator process that the user is talking to directly. It does
**not** apply inside Task-tool subagents (see the next subsection).

The working directory **persists across Bash calls** in the main
session. After one bare `cd`, every subsequent command runs in the
new CWD without re-stating it.

### Forbidden command forms — hook will deny

Three command shapes are **forbidden** and the auto-approve hook will
return a `deny` verdict on PreToolUse. Don't generate them.

**Forbidden form 1**: `cd <path> && <command>` (any compound starting
with `cd <path> &&`).

**Forbidden form 2**: `git -C <abs-path> <subcommand>`.

**Forbidden form 3**: subshells with `;` (e.g. `(cd <path>; <cmd>)`)
— these trip an unhandled-node walker bug in the harness.

**Why these are forbidden, not just discouraged:**

- The CVE-2025-59536 hardcoded harness gate prompts on
  `cd <path> && git ...` regardless of hook approvals.
- The harness also prompts on plain `git -C <abs-path> <subcommand>`
  even when the hook returns `allow` (cause not yet diagnosed; see
  #78).
- Subshells with `;` hit a separate harness walker bug.
- All three forms force the user to manually approve every command
  in a worktree workflow. The two reopens of issue #78 are evidence
  that prompt-level "don't generate this" guidance is insufficient,
  hence the hook-level deny.

The deny fires on PreToolUse only; in interactive
(`PermissionRequest`) sessions the harness's own approval prompt is
the user's escape hatch.

**Always use two separate Bash calls instead:**

1. First Bash call: `cd <absolute-path>`
2. Second (and subsequent) Bash calls: the bare command
   (`git log -3`, `git diff`, `make help`, `wc -l file`, etc.).

Both call types auto-approve cleanly:

- Bare `cd <path-at-or-below-repo-root>` is auto-approved by the
  hook.
- The bare command hits the per-subcommand allow-list directly.

The auto-approve hook applies to the **main session only**.
Subagents under `isolation: worktree` don't trigger the same hook
path because they're not executing `cd` commands at all (see next
subsection).

**Boundary rule:** `cd` is allowed at or below the repo root only
(includes `.claude/worktrees/...`, subdirectories, and back to root).
Never `cd` outside the repo root. If a fix needs another repo,
suggest the change in the conversation; don't implement it.

If the local directory (re)setting is wrong, tell the user. (Applies
to main session only.)

## Subagent context: cwd does NOT persist; use `isolation: worktree`

This subsection applies to **subagents launched via the Task tool**
(`issue-developer`, `issue-fixer`, `doc-updater`, `pr-reviewer`,
etc.). Per
[Anthropic's subagents documentation](https://code.claude.com/docs/en/sub-agents),
inside a subagent **`cd` commands do not persist between Bash or
PowerShell tool calls**. Every command after a bare `cd` runs in the
wrong directory. The "cwd persists" rule from the previous
subsection is wrong here.

There is also no working command-prefix pattern that both runs in
the right directory AND avoids harness prompts inside a subagent —
all three forbidden forms above still trip the harness in subagent
context.

**Solution: declare `isolation: worktree` in subagent frontmatter.**
The harness creates a fresh worktree under `.claude/worktrees/` and
starts the subagent's session inside it. From the first Bash call
onward, the subagent's cwd is already the worktree root. No `cd` to
the worktree is needed or possible. This sidesteps the harness
problem entirely rather than working around it.

### Rules inside an `isolation: worktree` subagent

- Run all commands as **bare commands**. The cwd is already the
  worktree root.
- A subagent **may** use `cd <subdir> && <cmd>` in a **single Bash
  call** to enter a subdirectory of its worktree (e.g. for a
  package-specific lint or build like `cd frontend && npm run build`
  or `cd backend && ruff check .`). The carve-out is narrow:
  **`<cmd>` must NOT be a `git` command.** The harness's hardcoded
  CVE-2025-59536 gate prompts on `cd <path> && git ...` regardless
  of context, so this still trips in a subagent. For git operations
  scoped to a subdirectory, run git from the worktree root and use
  pathspecs (`git diff -- <subdir>`, `git log -- <subdir>`,
  `git add <subdir>`) instead of cd-ing first. The next Bash call's
  cwd reverts to the worktree root automatically — that's the same
  cwd-doesn't-persist rule that makes a bare `cd` useless here,
  working in your favor: the subdirectory `cd` only applies to that
  one command, so you don't need to `cd` back.
- A subagent must **never** use `cd <path> && git <subcommand>`
  (CVE-2025-59536 gate, see above), `git -C <path> <subcommand>`
  (still triggers the fragile-arg-matching prompt), or subshells
  with `;` (still trips the walker bug). If a git operation seems
  to require any of these, restructure it: from the worktree root,
  most subdirectory-scoped git operations have a pathspec equivalent
  (`git diff -- <subdir>`, `git log -- <subdir>`, `git add <subdir>`).
- The harness's auto-created branch is named `worktree-agent-<hash>`
  (e.g. `worktree-agent-a39b0297dc3421b9e`). The subagent's first action
  should be to switch to its task-specific branch. Use the defensive
  `switch -c ... || switch ...` form so a leftover branch from a
  prior aborted run doesn't error the new run:
  `git switch -c issue-<N>-<slug> || git switch issue-<N>-<slug>`.

### End-of-run cleanup pattern

Before returning, an `isolation: worktree` subagent that pushed
work must run:

```text
git push
git checkout --detach          # release the feature-branch claim
git branch -D <feature-branch>
```

This releases the branch claim so a subsequent subagent's worktree
(e.g. `doc-updater` or `issue-fixer` operating on the same PR
branch) can check out the same branch. Without this cleanup, the
next worktree creation fails because git refuses to check out a
branch already claimed by another worktree.

**Why `--detach` and not `git checkout <base-branch>`:** in the
standard single-clone topology the orchestrator's primary clone is
already holding `<base-branch>` (typically `main`), so a subagent
worktree cannot `git checkout main` — git refuses to check out a
branch claimed by another worktree (`fatal: 'main' is already used
by worktree at '<primary-clone-path>'`). Detaching HEAD releases the
feature-branch claim equivalently: the feature branch is no longer
checked out by any worktree, so the next subagent's worktree can
re-check-it-out from `origin` without conflict. A named alternative
that also works is `git switch worktree-agent-<hash>` (the harness's
auto-created branch the worktree started on), but `--detach` is
simpler because it doesn't require recovering that name.

Subagents that only read remote state (e.g. `pr-reviewer`
reviewing a PR diff via `gh`) skip the cleanup — there's nothing
to push and no feature branch was checked out.

After the subagent returns, the **orchestrator** (main session)
runs `git worktree remove .claude/worktrees/<name>` to remove the
worktree directory itself. Do this **serially across the wave**,
not in parallel — see Anthropic issue
[#48927](https://github.com/anthropics/claude-code/issues/48927)
for a parallel-cleanup data-loss bug.

### Historical context

Issue #78 (and its two reopens) tracked attempts to make the
forbidden command forms work in subagents via prompt-level
guidance and hook tweaks. None held up. The
`isolation: worktree` pattern documented above is the working
replacement: subagents never `cd` and never use `-C`, so the
harness rules that broke the previous patterns no longer apply.

## Commit Messages

- First line: present-tense imperative verb and summary (e.g. "Add
  Lambda for account creation"); keep under 72 characters.
- Blank line.
- Detailed body: wrap at 132 characters; explain what and why.
- Use clear, descriptive commit messages.
- Focus on the "what" and "why", not the "how".

### Issue References

#### CRITICAL — never use closing keywords

When referencing GitHub issues, **never** use keywords that auto-close
issues:

- ❌ Never use: `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`,
  `resolve`, `resolves`, `resolved`.
- ❌ These keywords are case-insensitive and will auto-close the
  referenced issue.
- ✅ Use a `References: #N` trailer to link *other* related issues
  (predecessors, follow-ups, umbrella issues, etc.). For multiple,
  repeat the line.

**Why:** issues should only be closed manually after verification, not
automatically by commits.

#### CRITICAL — never self-reference the parent issue

A PR/commit for issue N must **not** include `References: #N` for that
same issue N:

- ❌ Never put the parent issue (the one being fixed) in
  `References:`. The PR is the work for that issue; its linkage is
  already established by branch name and PR title/description.
- ✅ `References:` lines list only *other* related issues — typically
  the ones the parent issue itself references in its body. If there
  are no other related issues, omit `References:` entirely.

**Applies to:**

- Commit messages
- Pull request descriptions
- Pull request commit squash messages

**Examples:**

No related issues — omit the trailer entirely:

```text
Add ARM64 support to CI/CD pipelines

Implements CodeBuild environment overrides for ARM64 Docker builds.
```

One other related issue (e.g. parent issue body says "blocked by
issue 42"):

```text
Add ARM64 support to CI/CD pipelines

Implements CodeBuild environment overrides for ARM64 Docker builds.

References: #42
```

Multiple other related issues (predecessors, follow-ups, umbrella
issues — but **not** the issue being fixed):

```text
Update authentication system

Refactors OAuth flow and adds MFA support.

References: #42
References: #57
References: #63
```

## Commit Signing

### IMPORTANT

- Do not sign commit messages. Use `git commit --no-gpg-sign` or
  equivalent.
- Do not sign by name (e.g. `🤖 Generated with [Claude Code]` or
  `Co-Authored-By: Claude <noreply@anthropic.com>`).

## User Review Before Commit

After tests pass, ALWAYS pause and present:

- Summary of changes made
- Files modified with line counts
- Proposed commit message
- Test results

**Wait for user approval before running `git commit` or `git push`.**

The user may:

- Request changes to the code
- Request changes to the commit message
- Ask for additional testing
- Reject the changes entirely

## Never Commit Without Approval

- Never assume the user wants changes committed.
- Never commit "for convenience" or to "save progress".
- The user is in control of when commits happen.
- Explicit approval is required for every commit.

## Never Push Without Approval

### CRITICAL — pushing requires explicit approval

After committing (whether to main or release), ALWAYS:

1. Show the commit that was created.
2. Show what branch it's on.
3. Ask explicitly: "Do you want me to push this to `origin/{branch}`?"
4. Wait for explicit "yes", "push", or similar confirmation.
5. NEVER assume "go ahead" or "continue" means push.

**Special care for release branch:**

- Pushing to release triggers QA/Production pipelines.
- This requires explicit approval separate from commit approval.
- Never bundle commit + push into one operation without asking first.

## When Making Changes

1. **Ask for confirmation** before significant architectural changes.
2. **Test incrementally** — small commits with single-line messages.

## When Merging

Always first do a dry-run merge:
`git checkout TARGET_BRANCH && git merge --no-commit --no-ff main`.

Never squash merge.

Never delete the source branch.

## Fixing having committed things on the wrong branch

When you made a commit on the wrong branch:

1. **git stash** — save working changes.
2. **git reset --hard HEAD~1** — undo commit on wrong branch.
3. **git checkout CORRECT_BRANCH** — switch to correct branch.
4. **git stash pop** — re-apply the saved changes.
5. **git commit** — commit to correct branch.

## GitHub Sub-Issues (Parent/Child Relationships)

The `gh` CLI does not have built-in flags for sub-issues. Use the
GraphQL API.

### Get an issue's node ID

```bash
gh issue view <number> --json id -q .id
```

### Check if an issue already has a parent

```bash
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    issue(number: NUMBER) {
      id
      parent { id number title }
    }
  }
}'
```

### Add a sub-issue to a parent

```bash
gh api graphql -f query='
mutation {
  addSubIssue(input: {
    issueId: "PARENT_NODE_ID",
    subIssueId: "CHILD_NODE_ID"
  }) {
    issue { id }
    subIssue { id }
  }
}'
```

**Note:** an issue can only have one parent. If it already has a parent,
remove it first.

### Remove a sub-issue from its parent

```bash
gh api graphql -f query='
mutation {
  removeSubIssue(input: {
    issueId: "PARENT_NODE_ID",
    subIssueId: "CHILD_NODE_ID"
  }) {
    issue { id }
    subIssue { id }
  }
}'
```

### List sub-issues of a parent

```bash
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    issue(number: NUMBER) {
      subIssues(first: 20) {
        nodes { id number title }
      }
    }
  }
}'
```

## GitHub Issue Comments

### Check Issue Metadata First

Before adding comments to issues:

1. **Check existing relationships** — use `gh issue view <number>` to
   see:
   - Blocking/blocked by relationships
   - Related issues
   - Assignees
   - Projects
   - Milestones

2. **Don't duplicate metadata in comments.**
   - Issue relationships (blocks, blocked by, related to) belong in
     issue metadata, not comments.
   - If an issue already blocks another issue, don't mention
     "Related to #X" in comments.

3. **Focus comments on technical details.**
   - Root cause analysis
   - Solution implementation
   - Verification steps
   - Code changes made

4. **When to mention other issues in comments.**
   - Only when adding NEW context not captured in existing
     relationships.
   - When explaining how a fix in this issue affects work in another
     issue.
   - When dependencies changed and relationships need updating.

### Example

```bash
# Check issue metadata before commenting
gh issue view 79

# See it already blocks #78
# Don't add "Related to #78" in comment
# Focus comment on the technical fix
```
