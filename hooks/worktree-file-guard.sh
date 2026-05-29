#!/bin/bash
# worktree-file-guard.sh
#
# PreToolUse hook that denies Edit, Write, and MultiEdit calls whose
# resolved absolute file_path falls outside the active worktree root.
#
# Only engages when the session's cwd is inside a
# .claude/worktrees/agent-*/ worktree (i.e. an isolation: worktree
# subagent). The main session is unaffected — it legitimately edits
# primary-clone files.
#
# Read is intentionally NOT guarded. Subagents legitimately Read files
# outside the worktree (e.g. ~/.claude/CLAUDE.md, ~/.claude/rules/*).
# The problem this hook defends against is *writes* landing in the
# primary clone, not all out-of-tree reads.
#
# Exit 0 with JSON  = deny the call (with reason)
# Exit 0 with no output = fall through (allow)
#
# References: #188, anthropics/claude-code#62547

set -euo pipefail

INPUT=$(cat)

# --- Am I in a worktree subagent? ---
# The harness places worktrees at <primary-clone>/.claude/worktrees/agent-<hash>/
# Check if the current git toplevel matches that pattern.
WORKTREE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# Pattern: .../.claude/worktrees/agent-<hex>/
# If not in a worktree, fall through silently (main session).
if ! echo "$WORKTREE_ROOT" | grep -qE '/\.claude/worktrees/agent-[a-f0-9]+$'; then
  exit 0
fi

# --- Extract the primary clone root ---
# Strip the /.claude/worktrees/agent-<hash> suffix.
PRIMARY_CLONE=$(echo "$WORKTREE_ROOT" | sed -E 's|/\.claude/worktrees/agent-[a-f0-9]+$||')

# --- Extract file_path from the tool input ---
# Edit and Write use .tool_input.file_path
# MultiEdit uses .tool_input.file_path as well (it's the same shape)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# If no file_path, nothing to guard
[ -z "$FILE_PATH" ] && exit 0

# --- Resolve the file_path ---
# Use a combination of approaches to resolve the path:
# 1. If the file exists, use realpath to resolve symlinks and ..
# 2. If the file doesn't exist but its parent does, resolve the parent
#    and append the filename
# 3. Fall back to a textual canonicalization (remove . and .. segments)
if [ -e "$FILE_PATH" ]; then
  RESOLVED=$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$FILE_PATH" 2>/dev/null) || RESOLVED="$FILE_PATH"
elif [ -d "$(dirname "$FILE_PATH")" ]; then
  PARENT=$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$(dirname "$FILE_PATH")" 2>/dev/null) || PARENT="$(dirname "$FILE_PATH")"
  RESOLVED="${PARENT}/$(basename "$FILE_PATH")"
else
  # Textual canonicalization: use python to resolve .. and . without
  # requiring the path to exist
  RESOLVED=$(python3 -c "import os, sys; print(os.path.normpath(os.path.abspath(sys.argv[1])))" "$FILE_PATH" 2>/dev/null) || RESOLVED="$FILE_PATH"
fi

# --- Containment check ---
# The resolved path must start with the worktree root.
# If it does, fall through (allow).
if [[ "$RESOLVED" == "$WORKTREE_ROOT" || "$RESOLVED" == "$WORKTREE_ROOT/"* ]]; then
  exit 0
fi

# --- The path is outside the worktree. Deny. ---

# Build a helpful message. If the path is inside the primary clone,
# we can suggest the correct worktree-relative path.
DENY_REASON=""
if [[ "$RESOLVED" == "$PRIMARY_CLONE" || "$RESOLVED" == "$PRIMARY_CLONE/"* ]]; then
  # The path landed in the primary clone. Calculate what the correct
  # worktree path would be.
  RELATIVE="${RESOLVED#"$PRIMARY_CLONE"/}"
  CORRECT_PATH="${WORKTREE_ROOT}/${RELATIVE}"
  DENY_REASON="${TOOL_NAME} denied: file_path '${FILE_PATH}' resolves to the primary clone (${RESOLVED}), not the active worktree. Use the worktree-anchored path instead: ${CORRECT_PATH}. Anchor all absolute paths to \$(git rev-parse --show-toplevel). See issue #188."
else
  DENY_REASON="${TOOL_NAME} denied: file_path '${FILE_PATH}' resolves outside the active worktree root (${WORKTREE_ROOT}). Resolved to: ${RESOLVED}. Edit/Write/MultiEdit must target files inside the worktree. See issue #188."
fi

jq -n --arg reason "$DENY_REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
