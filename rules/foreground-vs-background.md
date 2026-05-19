# Foreground vs Background

When a foreground subagent stops and asks for input, do NOT resume it
via `SendMessage`. `SendMessage` resumes the target in the background
by design, which breaks the permission-prompt channel: anything the
resumed agent runs that needs ask-list approval will be denied with a
generic "Permission to use Bash has been denied" message — no rule
name, no path for the user to approve.

## When this matters

- A foreground subagent runs a command that triggers an ask-list
  prompt. The prompt routes to the active session; the user approves;
  the command runs. Normal flow.
- A foreground subagent stops to ask the user for input (e.g.
  credential refresh, design decision).
- The user resolves the blocker and tells the orchestrator to
  continue.
- The orchestrator reaches for `SendMessage` because the `Agent` tool
  description says it's the way to "continue a previously spawned
  agent." But `SendMessage` resumption runs the target in the
  background. The next ask-list command in the resumed agent silently
  fails.

## What to do instead

When you need to continue a stopped subagent's work:

1. **If the blocked work is orchestrator-allowed plumbing** (git push
   of an agent's commit, fast-forward pull of main after a merge,
   worktree cleanup), do it from the orchestrator's own foreground
   session. The agent definition for the orchestrator already permits
   this category of work.

2. **If the blocked work needs the subagent's context** (e.g. continue
   editing files the agent had open, run agent-specific commands),
   spawn a fresh foreground `Agent` call with the resume context
   inline. Pass the original brief plus the new instruction. You lose
   the prior conversation-history continuity but keep the foreground
   permission-prompt channel.

3. **Never use `SendMessage` to bridge a "needs user input" stop.**

## Why this rule exists separately from "spawn foreground"

The existing rule in `skills/issue-address/SKILL.md` says "when
spawning teammates, do not run them in the background." That rule
covers initial spawning. It does NOT cover resumption — and resumption
via `SendMessage` is the failure mode that actually keeps biting.

## Scope

Applies to the main session and to any orchestrator skill that
manages teammate agents (`/issue-address`, future flows). Subagents
themselves pick up this rule via the `~/.claude/CLAUDE.md` include
mechanism, but the primary audience is the orchestrator — it's the
one deciding whether to resume vs. spawn vs. self-do.
