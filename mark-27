#!/bin/bash
# auto-approve-compound-commands.sh
#
# Hook for both PermissionRequest (interactive) and PreToolUse (headless).
# Auto-approves Bash commands where every part is either:
#   - a `cd` into a path at or below the repo root, or
#   - a `git -C <path> <subcommand>` where <path> is at or below the repo
#     root (the `-C <path>` is rewritten away and the rest is matched
#     against the per-subcommand allow-list), or
#   - a command matching the allow-list in settings.json.
#
# Compound commands (split on `&&`, `||`, `;`, `|`) are checked part by
# part. Standalone commands are checked as a single part — same logic.
#
# Exit 0 with JSON  = allow the command
# Exit 0 with no output = fall through to normal approval prompt
#
# References: #32, #78

set -euo pipefail

INPUT=$(cat)

# Extract hook event name and command
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Nothing to do if no command
[ -z "$COMMAND" ] && exit 0

# Detect repo root (best effort; bail if not in a git repo)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# --- Forbidden-form deny gate ---
#
# Two command shapes are explicitly forbidden by git-workflow.md and have
# repeatedly slipped through despite prompt-level instructions:
#
#   1. `cd <path> && <command>` — the CVE-2025-59536 hardcoded harness gate
#      prompts on this regardless of hook decisions. Forces manual approval
#      for every workflow command.
#   2. `git -C <abs-path> <subcommand>` — the harness prompts on these too,
#      even when the hook returns `allow` (cause not yet diagnosed; see #78).
#
# Both have a working alternative: two separate Bash calls — first
# `cd <path>`, then the bare command. CWD persists across calls.
#
# Deny these forms outright with a message that names the correct form, so
# the agent's self-correction loop fixes the next attempt instead of relying
# on prompt adherence (which has failed twice).
#
# Detection runs against the whole command string and is anchored to
# start-of-string OR an operator boundary (&&, ||, ;, |), so the gate
# catches the forbidden shape *anywhere* in a compound — not just at the
# start. Examples that all DENY:
#   cd /foo && git status
#   git status && cd /foo && git diff
#   git -C /foo log
#   echo --- && git -C /foo log
#
# Limitation: doesn't tokenize quoted strings (same limitation as the
# existing per-part allow-list logic below). A literal like
#   echo 'cd /foo && bar'
# would false-trigger. Acceptable trade-off; agents don't generate that.
#
# Only emitted on PreToolUse (which supports a deny verdict).
# PermissionRequest does not support deny in the same shape, so we fall
# through there — the harness will still prompt, but at least the
# behavior is consistent with prior issues.
if [ "$HOOK_EVENT" = "PreToolUse" ]; then
  DENY_REASON=""
  # cd <path> && — at start, or after an operator. Regex requires `cd`
  # followed by at least one non-space/non-operator token (the path),
  # then `&&`. This excludes bare `cd` (no arg) and excludes `cd ; X`,
  # `cd | X`, `cd || X` — only the `&&` form is the harness-gate trigger.
  if echo "$COMMAND" | grep -qE '(^|&&|\|\||;|\|)[[:space:]]*cd[[:space:]]+[^[:space:];|&]+[[:space:]]*&&'; then
    DENY_REASON="Forbidden form 'cd <path> && <command>'. Use two separate Bash calls: first 'cd <path>', then the bare '<command>'. CWD persists across calls. See profiles/edwin-dev/.claude/rules/git-workflow.md and issue #78."
  # git -C <abs-path> — at start, or after an operator. Restricted to
  # absolute paths (leading `/`, optionally preceded by a single or
  # double quote) so the gate doesn't false-deny the (hypothetical,
  # rare) `git -C ./relative` form. Both relative and absolute fall
  # through to the existing per-part `git -C` rewriter below in the
  # absolute-relative case; in practice agents always generate
  # absolute paths (the documented failure mode). The optional quote
  # prefix `["'\'']?` catches `git -C "/abs"` and `git -C '/abs'`,
  # which would otherwise slip past this educational deny gate.
  elif echo "$COMMAND" | grep -qE '(^|&&|\|\||;|\|)[[:space:]]*git[[:space:]]+-C[[:space:]]+["'\'']?/'; then
    DENY_REASON="Forbidden form 'git -C <abs-path> <subcommand>'. The harness prompts on these even when allow-listed. Use two separate Bash calls: first 'cd <abs-path>', then the bare 'git <subcommand>'. See profiles/edwin-dev/.claude/rules/git-workflow.md and issue #78."
  fi
  if [ -n "$DENY_REASON" ]; then
    jq -n --arg reason "$DENY_REASON" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  fi
fi

# --- Build allow-list from settings.json ---
# Look for settings.json relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_FILE="${SCRIPT_DIR}/../settings.json"

ALLOW_PREFIXES=()
if [ -f "$SETTINGS_FILE" ]; then
  # Extract Bash(...) allow entries -> command prefix (before the colon or closing paren)
  # e.g. "Bash(git status:*)" -> "git status"
  #      "Bash(npm install)"  -> "npm install"
  while IFS= read -r prefix; do
    [ -n "$prefix" ] && ALLOW_PREFIXES+=("$prefix")
  done < <(
    jq -r '.permissions.allow[]' "$SETTINGS_FILE" 2>/dev/null \
      | grep '^Bash(' \
      | sed 's/^Bash(//; s/)$//' \
      | sed 's/:[*]$//' \
      | sort -u
  )
fi

# Fallback: if we could not read any prefixes, bail out
if [ ${#ALLOW_PREFIXES[@]} -eq 0 ]; then
  exit 0
fi

# --- Path resolution helper ---
# Resolves a path under REPO_ROOT and prints the absolute path on stdout.
# Returns 0 if the path is at or below REPO_ROOT, 1 otherwise.
# Relative paths are resolved against REPO_ROOT. Non-existent dirs without
# `..` use the absolute path as-is (supports worktree and new-dir paths).
# NOTE: uses logical-path semantics; does NOT resolve symlinks. See #81.
resolve_under_repo_root() {
  local p="$1"
  # Reject paths that bash will expand at runtime (~, ~user, $VAR).
  # The helper does literal-prefix containment, so `~` would synthetically
  # pass (`$REPO_ROOT/~` starts with `$REPO_ROOT/`), but bash expands `~`
  # to `$HOME` at execution time — outside the repo. Same for `$HOME`,
  # `$1`, etc.
  if [[ "$p" == "~"* || "$p" == \$* ]]; then
    return 1
  fi
  if [[ "$p" != /* ]]; then
    p="${REPO_ROOT}/${p}"
  fi
  if [[ -d "$p" ]]; then
    p=$(cd "$p" 2>/dev/null && pwd) || return 1
  elif [[ "$p" == *".."* ]]; then
    return 1
  fi
  if [[ "$p" == "$REPO_ROOT" || "$p" == "$REPO_ROOT/"* ]]; then
    printf '%s\n' "$p"
    return 0
  fi
  return 1
}

# --- Split command on compound operators ---
# Replace || first (before |), then &&, then ;, then |
# Use a unique delimiter that won't appear in commands
DELIM=$'\x01'
SPLIT_CMD="$COMMAND"
SPLIT_CMD=$(echo "$SPLIT_CMD" | sed "s/||/${DELIM}/g")
SPLIT_CMD=$(echo "$SPLIT_CMD" | sed "s/&&/${DELIM}/g")
SPLIT_CMD=$(echo "$SPLIT_CMD" | sed "s/;/${DELIM}/g")
SPLIT_CMD=$(echo "$SPLIT_CMD" | sed "s/|/${DELIM}/g")

# --- Check each part ---
ALL_SAFE=true
while IFS="$DELIM" read -r -d '' part || [ -n "$part" ]; do
  # Trim whitespace
  part=$(echo "$part" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -z "$part" ] && continue

  # Strip trailing redirections to /dev/null (e.g. 2>/dev/null, >/dev/null,
  # `> /dev/null`, `2> /dev/null`) so they don't pollute path extraction
  # or prefix matching.
  # Only /dev/null is stripped — redirections to real files fall through
  # to manual approval to prevent silent data exfiltration.
  part=$(echo "$part" | sed -E 's/[[:space:]]*[0-9]*>[[:space:]]*\/dev\/null[[:space:]]*$//')

  # Reject any remaining redirect to a real file. /dev/null was stripped
  # above; if `>` (with optional fd number) still appears, the command
  # writes somewhere on disk. The prefix matcher would otherwise approve
  # `git status > /tmp/exfil.txt` via `Bash(git status:*)` because the
  # part starts with `git status `. Reject explicitly.
  # Excludes `>|` (clobber-pipe) and `>>` is handled by the same `>` match.
  if echo "$part" | grep -qE '(^|[[:space:]])[0-9]*>[^|]'; then
    ALL_SAFE=false
    break
  fi

  # Check if this is a `git -C <path> <subcommand>` command.
  # If <path> resolves to the repo root or below, rewrite the part to drop
  # `-C <path>` so the per-subcommand allow-list check below decides
  # (e.g. `Bash(git log:*)` approves; `Bash(git push)` etc. only if
  # explicitly allow-listed). If <path> is outside the repo root, the
  # part falls through to manual approval.
  #
  # Limitation: only the FIRST `-C <path>` arg is path-checked. A second
  # `-C` later in the command isn't validated by this branch — but the
  # rewritten part still has to pass the subcommand allow-list, so this
  # is safe in practice.
  if echo "$part" | grep -qE '^git[[:space:]]+-C[[:space:]]+'; then
    # Strip "git -C " and capture the rest
    REMAINDER=$(echo "$part" | sed -E 's/^git[[:space:]]+-C[[:space:]]+//')
    # Extract the path arg (first token, possibly quoted) and the rest
    if [[ "$REMAINDER" =~ ^\"([^\"]+)\"(.*)$ ]] || [[ "$REMAINDER" =~ ^\'([^\']+)\'(.*)$ ]]; then
      GIT_C_PATH="${BASH_REMATCH[1]}"
      GIT_C_REST="${BASH_REMATCH[2]}"
    else
      GIT_C_PATH="${REMAINDER%% *}"
      if [[ "$REMAINDER" == "$GIT_C_PATH" ]]; then
        GIT_C_REST=""
      else
        GIT_C_REST="${REMAINDER#"$GIT_C_PATH"}"
      fi
    fi

    if resolve_under_repo_root "$GIT_C_PATH" >/dev/null; then
      # Rewrite the part to "git <rest>" and fall through to allow-list check
      part="git${GIT_C_REST}"
      part=$(echo "$part" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    else
      ALL_SAFE=false
      break
    fi
  fi

  # Check if this is a cd command with an argument.
  # Bare "cd" (no arguments) is intentionally not matched here -- it changes
  # to $HOME which is outside the repo, so it falls through to normal approval.
  # Tilde/variable forms like "cd ~" or "cd $HOME" are also not resolved;
  # they fail the path-resolution step below and safely fall through.
  if echo "$part" | grep -qE '^cd[[:space:]]+'; then
    # Extract the target path
    CD_TARGET=$(echo "$part" | sed 's/^cd[[:space:]]*//')
    # Remove surrounding quotes if present
    CD_TARGET=$(echo "$CD_TARGET" | sed "s/^['\"]//;s/['\"]$//")

    if resolve_under_repo_root "$CD_TARGET" >/dev/null; then
      continue
    else
      ALL_SAFE=false
      break
    fi
  fi

  # Check against the allow-list prefixes
  MATCHED=false
  for prefix in "${ALLOW_PREFIXES[@]}"; do
    if [[ "$part" == "$prefix" || "$part" == "$prefix "* ]]; then
      MATCHED=true
      break
    fi
  done

  if [ "$MATCHED" = "false" ]; then
    ALL_SAFE=false
    break
  fi
done < <(echo "$SPLIT_CMD" | tr "$DELIM" '\0')

# --- Return appropriate response ---
if [ "$ALL_SAFE" = "true" ]; then
  REASON="All parts match allow-list or are safe cd / git -C operations"

  if [ "$HOOK_EVENT" = "PermissionRequest" ]; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PermissionRequest",
        decision: {
          behavior: "allow"
        }
      }
    }'
  elif [ "$HOOK_EVENT" = "PreToolUse" ]; then
    jq -n --arg reason "$REASON" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        permissionDecisionReason: $reason
      }
    }'
  fi
fi

exit 0
