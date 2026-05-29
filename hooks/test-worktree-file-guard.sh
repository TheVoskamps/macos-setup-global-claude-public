#!/bin/bash
# test-worktree-file-guard.sh
#
# Test suite for worktree-file-guard.sh PreToolUse hook.
#
# The hook only engages when git rev-parse --show-toplevel returns a
# path matching .claude/worktrees/agent-<hex>/. To test in a normal
# checkout (where --show-toplevel returns the repo root, NOT a worktree
# path), we create a temporary fake worktree directory structure and
# override the hook's git call via a PATH-prepended shim.
#
# Usage:
#   bash hooks/test-worktree-file-guard.sh
#
# Exit 0 if all cases pass, 1 if any fail. Prints PASS/FAIL per case.
#
# Verdicts:
#   DENY         hookSpecificOutput.permissionDecision == "deny"
#   ALLOW        hookSpecificOutput.permissionDecision == "allow"
#   FALL_THROUGH empty stdout (hook chose not to decide)
#
# References: #188

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/worktree-file-guard.sh"

if [ ! -x "$HOOK" ]; then
  echo "ERROR: hook not executable at $HOOK" >&2
  exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

# --- Set up a fake worktree structure ---
# We need git rev-parse --show-toplevel to return a path that matches
# the .claude/worktrees/agent-<hex>/ pattern. We'll create a real
# directory and use a git shim to fake the output.
REAL_REPO_ROOT=$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel)
FAKE_WORKTREE="${REAL_REPO_ROOT}/.claude/tmp/test-worktree-file-guard/fake-primary/.claude/worktrees/agent-deadbeef1234"
FAKE_PRIMARY="${REAL_REPO_ROOT}/.claude/tmp/test-worktree-file-guard/fake-primary"

# Clean up from any prior run
rm -rf "${REAL_REPO_ROOT}/.claude/tmp/test-worktree-file-guard"

# Create fake worktree directory with some files
mkdir -p "$FAKE_WORKTREE/rules"
mkdir -p "$FAKE_WORKTREE/hooks"
echo "test" > "$FAKE_WORKTREE/rules/test-rule.md"
echo "test" > "$FAKE_WORKTREE/hooks/test-hook.sh"

# Create a file in the fake primary clone (the leak target)
mkdir -p "$FAKE_PRIMARY/rules"
echo "primary" > "$FAKE_PRIMARY/rules/test-rule.md"

# Create git shim directories that override `git rev-parse --show-toplevel`
# Worktree shim: returns the fake worktree path (simulates subagent context)
SHIM_DIR="${REAL_REPO_ROOT}/.claude/tmp/test-worktree-file-guard/shim"
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/git" << 'SHIMEOF'
#!/bin/bash
# Git shim: intercept rev-parse --show-toplevel, pass everything else through
if [[ "$*" == "rev-parse --show-toplevel" ]]; then
  echo "$FAKE_WORKTREE_FOR_SHIM"
else
  /usr/bin/git "$@"
fi
SHIMEOF
chmod +x "$SHIM_DIR/git"

# Main-session shim: returns a non-worktree path (simulates main session)
# This is needed because the test itself may run inside a real worktree,
# so bare git rev-parse --show-toplevel would return a worktree path.
# We derive a "primary clone" path by stripping the .claude/worktrees/agent-*
# suffix if present, so the hook sees a path that does NOT match the
# worktree pattern and falls through.
MAIN_SESSION_ROOT=$(echo "$REAL_REPO_ROOT" | sed -E 's|/\.claude/worktrees/agent-[a-f0-9]+$||')
MAIN_SHIM_DIR="${REAL_REPO_ROOT}/.claude/tmp/test-worktree-file-guard/main-shim"
mkdir -p "$MAIN_SHIM_DIR"
cat > "$MAIN_SHIM_DIR/git" << MAINSHIMEOF
#!/bin/bash
if [[ "\$*" == "rev-parse --show-toplevel" ]]; then
  echo "${MAIN_SESSION_ROOT}"
else
  /usr/bin/git "\$@"
fi
MAINSHIMEOF
chmod +x "$MAIN_SHIM_DIR/git"

# run_test LABEL TOOL_NAME FILE_PATH EXPECTED [USE_SHIM]
#
# Feeds a PreToolUse JSON event to the hook and compares the verdict
# against EXPECTED in {DENY, ALLOW, FALL_THROUGH}.
# USE_SHIM defaults to "yes". Set to "no" to test main-session (non-worktree) behavior.
run_test() {
  local label="$1"
  local tool_name="$2"
  local file_path="$3"
  local expected="$4"
  local use_shim="${5:-yes}"

  local input
  input=$(jq -n --arg tool "$tool_name" --arg path "$file_path" '{
    hook_event_name: "PreToolUse",
    tool_name: $tool,
    tool_input: { file_path: $path }
  }')

  local output
  if [ "$use_shim" = "yes" ]; then
    output=$(echo "$input" | FAKE_WORKTREE_FOR_SHIM="$FAKE_WORKTREE" PATH="${SHIM_DIR}:${PATH}" "$HOOK" 2>/dev/null || true)
  else
    # Use the main-session shim so the hook sees a non-worktree toplevel,
    # even when running from inside a real worktree.
    output=$(echo "$input" | PATH="${MAIN_SHIM_DIR}:${PATH}" "$HOOK" 2>/dev/null || true)
  fi

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
    printf 'PASS  %-12s  %s\n' "$expected" "$label"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    printf 'FAIL  expected=%-12s got=%-12s  %s\n' "$expected" "$verdict" "$label"
    printf '      tool=%s  file_path=%s\n' "$tool_name" "$file_path"
    if [ -n "$output" ]; then
      printf '      output: %s\n' "$output"
    fi
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "Running worktree-file-guard tests against: $HOOK"
echo "Fake worktree root: $FAKE_WORKTREE"
echo "Fake primary clone: $FAKE_PRIMARY"
echo

# =============================================================
# Tests in worktree context (shim active)
# =============================================================

echo "--- Worktree context (shim active) ---"
echo

# T1: Edit a file inside the worktree -- should FALL_THROUGH (allowed)
run_test "T1  Edit file inside worktree" \
  "Edit" \
  "${FAKE_WORKTREE}/rules/test-rule.md" \
  "FALL_THROUGH"

# T2: Write a file inside the worktree -- should FALL_THROUGH (allowed)
run_test "T2  Write file inside worktree" \
  "Write" \
  "${FAKE_WORKTREE}/hooks/test-hook.sh" \
  "FALL_THROUGH"

# T3: Edit a file in the PRIMARY CLONE -- should DENY
run_test "T3  Edit file in primary clone (the leak)" \
  "Edit" \
  "${FAKE_PRIMARY}/rules/test-rule.md" \
  "DENY"

# T4: Write a file in the primary clone -- should DENY
run_test "T4  Write file in primary clone" \
  "Write" \
  "${FAKE_PRIMARY}/rules/test-rule.md" \
  "DENY"

# T5: MultiEdit a file in the primary clone -- should DENY
run_test "T5  MultiEdit file in primary clone" \
  "MultiEdit" \
  "${FAKE_PRIMARY}/rules/test-rule.md" \
  "DENY"

# T6: Edit a file completely outside any clone (e.g. /tmp) -- should DENY
run_test "T6  Edit file outside any clone (/tmp)" \
  "Edit" \
  "/tmp/some-file.md" \
  "DENY"

# T7: Edit with a path containing .. that escapes to primary clone
run_test "T7  Edit with .. escaping to primary clone" \
  "Edit" \
  "${FAKE_WORKTREE}/../../rules/test-rule.md" \
  "DENY"

# T8: Read a file outside the worktree -- Read is not guarded, so
#     this tool_name should not be handled at all (hook doesn't fire
#     on Read because settings.json doesn't wire it). But if the hook
#     IS called with Read, it should FALL_THROUGH because the hook only
#     denies Edit/Write/MultiEdit.
#     ... actually the hook denies ALL tool_names that have a file_path
#     outside the worktree. The settings.json wiring controls WHICH tools
#     trigger the hook. So if Read triggers the hook, it gets denied.
#     But settings.json will NOT wire Read to this hook.
#     For completeness, test that Edit (wired) gets denied.
run_test "T8  Edit targeting ~/.claude/CLAUDE.md" \
  "Edit" \
  "${HOME}/.claude/CLAUDE.md" \
  "DENY"

# T9: Edit a NEW file inside the worktree (parent exists, file doesn't)
run_test "T9  Edit new file inside worktree (parent exists)" \
  "Edit" \
  "${FAKE_WORKTREE}/rules/new-rule.md" \
  "FALL_THROUGH"

# T10: Write a new file in a new subdir inside the worktree
#      (parent doesn't exist -- uses normpath fallback)
run_test "T10 Write new file in new subdir inside worktree" \
  "Write" \
  "${FAKE_WORKTREE}/new-dir/new-file.md" \
  "FALL_THROUGH"

# T11: Edit with no file_path at all -- should FALL_THROUGH (nothing to guard)
local_input='{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{}}'
local_output=$(echo "$local_input" | FAKE_WORKTREE_FOR_SHIM="$FAKE_WORKTREE" PATH="${SHIM_DIR}:${PATH}" "$HOOK" 2>/dev/null || true)
if [ -z "$local_output" ]; then
  printf 'PASS  %-12s  %s\n' "FALL_THROUGH" "T11 Edit with no file_path"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  printf 'FAIL  expected=%-12s got=non-empty  %s\n' "FALL_THROUGH" "T11 Edit with no file_path"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo
echo "--- Main session context (no shim -- not in a worktree) ---"
echo

# =============================================================
# Tests in main-session context (no shim -- real git toplevel)
# =============================================================

# T12: Edit a file in the repo -- main session, should FALL_THROUGH
run_test "T12 Edit in repo (main session)" \
  "Edit" \
  "${REAL_REPO_ROOT}/rules/core-principles.md" \
  "FALL_THROUGH" \
  "no"

# T13: Edit a file outside the repo -- main session, should FALL_THROUGH
#      (main session is NOT restricted by this hook)
run_test "T13 Edit outside repo (main session)" \
  "Edit" \
  "/tmp/some-file.md" \
  "FALL_THROUGH" \
  "no"

# T14: Write anywhere -- main session, should FALL_THROUGH
run_test "T14 Write anywhere (main session)" \
  "Write" \
  "${HOME}/.claude/CLAUDE.md" \
  "FALL_THROUGH" \
  "no"

# =============================================================
# Clean up
# =============================================================
rm -rf "${REAL_REPO_ROOT}/.claude/tmp/test-worktree-file-guard"

echo
echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
