#!/bin/bash
# test-deny-gate.sh
#
# Regression test suite for auto-approve-compound-commands.sh deny gate.
#
# Covers the original 12-case PR #91 matrix plus the M1 quoted-path cases
# added in the follow-up review. Run from anywhere; the script locates the
# hook relative to its own location.
#
#   bash profiles/edwin-dev/.claude/hooks/test-deny-gate.sh
#
# Exit 0 if all cases pass, 1 if any fail. Prints PASS/FAIL per case.
#
# Verdicts:
#   DENY         hookSpecificOutput.permissionDecision == "deny"
#   ALLOW        hookSpecificOutput.permissionDecision == "allow"
#   FALL_THROUGH empty stdout (hook chose not to decide)
#
# References: #78

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/auto-approve-compound-commands.sh"

if [ ! -x "$HOOK" ]; then
  echo "ERROR: hook not executable at $HOOK" >&2
  exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

# run_test LABEL COMMAND EXPECTED
#
# Feeds a PreToolUse JSON event (with the given Bash command) to the hook
# and compares the verdict against EXPECTED ∈ {DENY, ALLOW, FALL_THROUGH}.
run_test() {
  local label="$1"
  local cmd="$2"
  local expected="$3"

  local input
  input=$(jq -n --arg cmd "$cmd" '{
    hook_event_name: "PreToolUse",
    tool_name: "Bash",
    tool_input: { command: $cmd }
  }')

  local output
  output=$(echo "$input" | "$HOOK" 2>/dev/null || true)

  local verdict
  if [ -z "$output" ]; then
    verdict="FALL_THROUGH"
  else
    local decision
    decision=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)
    case "$decision" in
      deny)  verdict="DENY" ;;
      allow) verdict="ALLOW" ;;
      *)     verdict="FALL_THROUGH" ;;
    esac
  fi

  if [ "$verdict" = "$expected" ]; then
    printf 'PASS  %-6s  %s\n' "$expected" "$label"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    printf 'FAIL  expected=%-6s got=%-12s  %s\n' "$expected" "$verdict" "$label"
    printf '      command: %s\n' "$cmd"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# A path that exists and is at/below the repo root (use the repo root
# itself — always present, always under itself). Picked at runtime so
# the script works in any worktree.
REPO_ROOT=$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel)

echo "Running deny-gate tests against: $HOOK"
echo "Repo root for ALLOW path tests: $REPO_ROOT"
echo

# --- Original 12 from PR #91 ---

# T1: cd <path> && git status — DENY (forbidden form 1, at start)
run_test "T1  cd <path> && git status" \
  "cd /tmp && git status" \
  "DENY"

# T2: cd <path> in the middle of a compound — DENY (boundary anchor)
run_test "T2  git status && cd <path> && git diff" \
  "git status && cd /tmp && git diff" \
  "DENY"

# T3: git -C <abs> log — DENY (forbidden form 2, at start)
run_test "T3  git -C <abs> log" \
  "git -C /tmp log" \
  "DENY"

# T4: git -C <abs> in middle of compound — DENY (boundary anchor)
run_test "T4  echo --- && git -C <abs> log" \
  "echo --- && git -C /tmp log" \
  "DENY"

# T5: multiple git -C <abs> instances — DENY (first match short-circuits)
run_test "T5  git -C <abs> a && b && git -C <abs> c" \
  "git -C /tmp log && echo mid && git -C /var status" \
  "DENY"

# T6: bare cd <path> under repo root — ALLOW
run_test "T6  bare cd <path-under-repo-root>" \
  "cd ${REPO_ROOT}" \
  "ALLOW"

# T7: bare git status — ALLOW (in allow-list)
run_test "T7  bare git status" \
  "git status" \
  "ALLOW"

# T8: git worktree remove — ALLOW (settings.json entry)
run_test "T8  git worktree remove ..." \
  "git worktree remove .claude/worktrees/foo" \
  "ALLOW"

# T9: git stash push — ALLOW (settings.json entry)
run_test "T9  git stash push ..." \
  "git stash push -m wip" \
  "ALLOW"

# T10: git branch --list — ALLOW (settings.json entry)
run_test "T10 git branch --list ..." \
  "git branch --list main" \
  "ALLOW"

# T11: git stash list — ALLOW (settings.json entry)
run_test "T11 git stash list" \
  "git stash list" \
  "ALLOW"

# T12: git stash show — ALLOW (settings.json entry)
run_test "T12 git stash show ..." \
  "git stash show stash@{0}" \
  "ALLOW"

# --- M1 follow-up cases: quoted absolute paths in `git -C` ---

# T13: git -C "<abs>" log — DENY (double-quoted absolute path)
run_test 'T13 git -C "<abs>" log (double-quoted)' \
  'git -C "/tmp" log' \
  "DENY"

# T14: git -C '<abs>' log — DENY (single-quoted absolute path)
run_test "T14 git -C '<abs>' log (single-quoted)" \
  "git -C '/tmp' log" \
  "DENY"

# Bonus regression: relative `git -C` should NOT be denied by the gate.
# It falls through to the per-part rewriter, which validates the path
# against repo root. With "./" (relative, doesn't start with `/`), the
# deny gate must skip and the rewriter accepts ./ as repo-root-or-below.
run_test "T15 git -C ./ log (relative path — gate must not deny)" \
  "git -C ./ log" \
  "ALLOW"

# T16: regression for the production-shape payload bug (issue #78).
# The deny gate previously read .hookEventName (camelCase) from the input
# payload, but the harness sends .hook_event_name (snake_case). The
# entire test suite passed against the broken hook because the test
# harness was wrong in the same direction. With the corrected input
# shape (now used by run_test above), this exact command from the
# issue's failing example must DENY.
run_test "T16 git -C <repo-root> fetch origin main (issue #78 regression)" \
  "git -C ${REPO_ROOT} fetch origin main" \
  "DENY"

echo
echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
