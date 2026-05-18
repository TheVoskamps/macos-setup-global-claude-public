# Escalation Discipline

Stop and report back — do NOT invent a workaround — when you encounter:

- **An environmental mismatch the issue does not describe.** Examples:
  the host Python rejects a dependency, the deployment target Python
  differs from the host, a required tool is missing, a credential
  has expired, a base image won't pull, a port is occupied.
- **A rule that contradicts another rule, or a rule that doesn't fit
  the situation.** Examples: the issue body tells you to use `/tmp/`
  but the agent rules forbid `/tmp/`; the rule says "verify in a venv"
  but the host can't build the deps.
- **A "fix" that requires more than what the issue describes.** Examples:
  the failing test is unrelated to your change; a wheel build fails for
  reasons that have nothing to do with the version bump in the issue.

These are NOT "implementation noise" to solve and move on. They are
decisions about which canonical path to take, and they shape every
future run. The human must see them in real time.

When you stop, report back with:

1. **The exact error or rule conflict**, verbatim. Quote the output;
   do not paraphrase.
2. **The options you see**, briefly — 2-4 options, no more. If you can
   identify a systemic answer (one that fixes a class of future runs,
   not just this one), say so.
3. **What you would do** if forced to pick. Then ask.

This rule is distinct from the "design decision" escalation rule in
`agents/issue-developer.md` and `agents/issue-fixer.md`, which covers
decisions about the fix being implemented. That rule applies only to
the developer and fixer agents (the ones implementing changes); this
rule applies to all four agents and to the main session. Both kinds of
decisions deserve escalation, but they cover different surfaces.

## What this rule does NOT require

You do not need to escalate every error. The bar is:

- The error is *not* about the fix you're working on (so it's not your
  fix that's wrong).
- The fix has *more than one reasonable resolution* (so picking one
  silently makes a non-trivial decision for the human).
- The resolution would *shape future runs*, not just this one (so the
  decision is systemic, not local).

Routine errors that fail one of those bars — a typo you made, a test
you broke, a lint error in your diff — keep solving yourself.

## Scope

Applies to the main session and to all four subagents (`issue-developer`,
`issue-fixer`, `doc-updater`, `pr-reviewer`). Subagents pick this up
automatically via the `~/.claude/CLAUDE.md` include mechanism (see
issue #68).
