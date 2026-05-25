#!/usr/bin/env bash

# Self-contained installer for the global Claude config public mirror.
#
# Clone this repo (the public mirror) somewhere, then run this script
# from inside that clone:
#
#     git clone git@github.com:TheVoskamps/global-claude-config-public.git
#     cd global-claude-config-public
#     ./.global-claude-config/install.sh
#
# What it does, in order:
#
#   1. Back up any existing `~/.claude/` by MOVING it aside to a
#      timestamped `~/.claude.backup.<ts>/`. That backup is always the
#      recovery path; the script never destroys it.
#   2. Install the clone by MOVING the whole clone (intact `.git` and
#      `origin` pointing at the public mirror) to `~/.claude/`. You can
#      later `git pull` in `~/.claude/` to update.
#   3. Additively overlay your previous `~/.claude/` files (from the
#      backup) on top of the freshly-installed clone, LOCAL WINS: your
#      old files overwrite the clone's where they collide. `.git` is
#      never overlaid.
#
# Properties:
#   - Idempotent / safe to re-run. If `~/.claude/` is already a clone of
#     the public mirror, the script reports that and exits without
#     moving anything.
#   - Non-destructive. The timestamped backup is the recovery path.
#   - Refuses to run from inside `~/.claude/` (the canonical copy there
#     is updated via `git pull`, not by re-running this installer).
#
# Standalone: no dependency on the `macos-setup` repo or any external
# script. It is modeled on the idioms of that repo's
# `scripts/claude_repo_setup.sh`, but copies in only what it needs.

set -euo pipefail

# --- Output helpers (inline; standalone script sources nothing) ------------

info()    { echo "-> $1"; }
success() { echo "[ok] $1"; }
error_exit() { echo "Error: $1" >&2; exit 1; }

# --- Origin URLs of the public mirror --------------------------------------
# Accepted forms when detecting an already-installed clone.

MIRROR_URL_SSH="git@github.com:TheVoskamps/global-claude-config-public.git"
MIRROR_URL_HTTPS="https://github.com/TheVoskamps/global-claude-config-public.git"

# --- Re-exec off a temp copy -----------------------------------------------
# Step 5 MOVES the clone (the directory this script lives in) onto
# `~/.claude/`. A running script whose file is being moved out from under
# it is fragile, so re-exec a throwaway copy of ourselves from a fresh
# temp dir first. The re-execed instance carries the resolved source root
# in an env var, so it no longer needs to live inside the clone.

if [[ -z "${CLAUDE_INSTALL_REEXEC:-}" ]]; then
    # Resolve the clone root from our own location BEFORE copying: the
    # script lives at <clone>/.global-claude-config/install.sh, so the
    # clone root is the parent of the script's directory.
    _scriptdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _src_root="$(cd "$_scriptdir/.." && pwd)"

    _tmpdir="$(mktemp -d)"
    _tmpcopy="$_tmpdir/install.sh"
    cp "${BASH_SOURCE[0]}" "$_tmpcopy"

    CLAUDE_INSTALL_REEXEC=1 \
    CLAUDE_INSTALL_SRC_ROOT="$_src_root" \
    CLAUDE_INSTALL_TMPDIR="$_tmpdir" \
        exec bash "$_tmpcopy" "$@"
fi

# From here on we are the re-execed copy living in a temp dir.

SRC_ROOT="${CLAUDE_INSTALL_SRC_ROOT:?internal error: CLAUDE_INSTALL_SRC_ROOT not set}"
SELF_TMPDIR="${CLAUDE_INSTALL_TMPDIR:-}"

# Best-effort cleanup of the temp copy on exit.
cleanup() {
    if [[ -n "$SELF_TMPDIR" ]] && [[ -d "$SELF_TMPDIR" ]]; then
        rm -rf "$SELF_TMPDIR" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# --- Absolute paths captured up front --------------------------------------

CLAUDE_DIR="$HOME/.claude"

# --- Repo detection --------------------------------------------------------

# Echo the URL git knows for a repo's `origin` remote, or "" if the
# directory isn't a git repo.
origin_url() {
    local dir="$1"
    [[ -d "$dir/.git" ]] || return 0
    git -C "$dir" config --get remote.origin.url 2>/dev/null || true
}

# Return 0 if `$CLAUDE_DIR` is already a clone of the public mirror.
claude_dir_is_our_clone() {
    local url
    url=$(origin_url "$CLAUDE_DIR")
    [[ "$url" == "$MIRROR_URL_SSH" ]] || [[ "$url" == "$MIRROR_URL_HTTPS" ]]
}

# --- Additive overlay ------------------------------------------------------
# Overlay every top-level entry under `$src` (excluding `.git`) onto
# `$dst`. Local wins: an entry that exists in both is overwritten by the
# `$src` (backup) version. After this runs, the user's pre-existing files
# are present in `~/.claude/`, with the clone's files where the user had
# none.
#
# Per-entry rules:
#   - `.git`:         skip (never overlay the clone's git metadata).
#   - Broken symlink: skip + warn (don't replace a real file with a dead
#                     pointer).
#   - Valid symlink:  copy as a symlink (`cp -RP`).
#   - Regular file:   copy, overwriting the clone's version.
#   - Directory:      deep-merge with local-wins.
#
# Kind-mismatch handling: BSD `cp` on macOS copies INTO an existing
# directory and follows a destination symlink rather than replacing it.
# To preserve "local wins", remove the destination first on any kind
# mismatch (or when the destination is a symlink) so the copy replaces
# cleanly. Same-kind dir->dir and file->file fall through to deep-merge /
# overwrite.
overlay_orig_onto_clone() {
    local src="$1"
    local dst="$2"
    info "Overlaying previous ~/.claude files from $src onto $dst (excluding .git)..."
    local entry
    while IFS= read -r -d '' entry; do
        local name
        name="$(basename "$entry")"
        [[ "$name" == ".git" ]] && continue
        local target="$dst/$name"

        if [[ -L "$entry" ]] && [[ ! -e "$entry" ]]; then
            local dead_target
            dead_target=$(readlink "$entry" 2>/dev/null || echo "<unreadable>")
            echo "Warning: skipping broken symlink: $entry -> $dead_target" >&2
            continue
        fi

        local src_kind dst_kind
        if   [[ -L "$entry"  ]]; then src_kind=L
        elif [[ -d "$entry"  ]]; then src_kind=D
        else                          src_kind=F
        fi
        if   [[ -L "$target" ]]; then dst_kind=L
        elif [[ -d "$target" ]]; then dst_kind=D
        elif [[ -e "$target" ]]; then dst_kind=F
        else                          dst_kind=
        fi

        if [[ -n "$dst_kind" ]] \
            && { [[ "$src_kind" != "$dst_kind" ]] || [[ "$dst_kind" == L ]]; }
        then
            rm -rf "$target"
        fi

        if [[ "$src_kind" == L ]]; then
            cp -RP "$entry" "$target"
        elif [[ "$src_kind" == D ]]; then
            mkdir -p "$target"
            cp -R "$entry"/. "$target"/
            info "  restored directory (local-wins merge): $name"
        else
            cp -p "$entry" "$target"
            info "  restored file (local wins): $name"
        fi
    done < <(find "$src" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
}

# --- Timestamped backup path -----------------------------------------------
# Never clobber an existing backup: if the same-second path already
# exists, append a numeric suffix until we find a free name.
unique_backup_path() {
    local base
    base="${CLAUDE_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    local candidate="$base"
    local n=1
    while [[ -e "$candidate" ]] || [[ -L "$candidate" ]]; do
        candidate="${base}.${n}"
        n=$((n + 1))
    done
    echo "$candidate"
}

# --- Main ------------------------------------------------------------------

main() {
    # Step 2 (self-protection): refuse to run from inside ~/.claude. The
    # canonical copy at ~/.claude is meant to be updated via `git pull`,
    # not by re-running this installer onto itself.
    if [[ "$SRC_ROOT" == "$CLAUDE_DIR" ]]; then
        echo
        info "This installer was started from inside $CLAUDE_DIR."
        info "It is not meant to run from there: the canonical copy at"
        info "$CLAUDE_DIR is updated with 'git -C \"$CLAUDE_DIR\" pull',"
        info "not by re-running this script onto itself. Nothing to do."
        exit 0
    fi

    # Idempotency: if ~/.claude is already a clone of the public mirror,
    # there is nothing to install. Don't move anything; don't create a
    # backup.
    if claude_dir_is_our_clone; then
        echo
        success "$CLAUDE_DIR is already a clone of the public mirror."
        info "Nothing to install. Update it later with:"
        info "  git -C \"$CLAUDE_DIR\" pull"
        exit 0
    fi

    info "Source clone: $SRC_ROOT"
    info "Target:       $CLAUDE_DIR"

    # Step 4: back up any existing ~/.claude by moving it aside.
    local backup=""
    if [[ -e "$CLAUDE_DIR" ]] || [[ -L "$CLAUDE_DIR" ]]; then
        backup="$(unique_backup_path)"
        info "Backing up existing $CLAUDE_DIR -> $backup"
        mv "$CLAUDE_DIR" "$backup"
    else
        info "No existing $CLAUDE_DIR found; nothing to back up."
    fi

    # Step 5: install by MOVING the whole clone to ~/.claude. This keeps
    # the clone's .git and origin intact (a local mv, NOT a git clone).
    info "Installing: moving clone $SRC_ROOT -> $CLAUDE_DIR"
    mkdir -p "$(dirname "$CLAUDE_DIR")"
    mv "$SRC_ROOT" "$CLAUDE_DIR"

    # Step 6: additively overlay the backed-up contents on top (local
    # wins), excluding .git.
    if [[ -n "$backup" ]]; then
        overlay_orig_onto_clone "$backup" "$CLAUDE_DIR"
    fi

    echo
    success "Installed the global Claude config into $CLAUDE_DIR."
    if [[ -n "$backup" ]]; then
        echo "Your previous ~/.claude/ contents are preserved at: $backup"
        echo "That backup is the recovery path; this script never deletes it."
        echo
        echo "Files you had before were overlaid on top of the clone"
        echo "(local wins) and show as dirty in 'git -C ~/.claude status'."
    fi
    echo "$CLAUDE_DIR is now a live clone of the public mirror; update it with:"
    echo "  git -C \"$CLAUDE_DIR\" pull"
}

main "$@"
