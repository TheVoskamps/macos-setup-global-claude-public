# global-claude-config

This repo contains the shared configuration of `~/.claude` and is meant
to be used by and in conjunction with `TheVoskamps/macos-setup`
functionality.

## Read-only public mirror

If you are reading this on `TheVoskamps/global-claude-config-public`,
that repo is a **read-only public mirror**. Issues are welcome here; we
triage and fix them in the upstream private repo. PRs are not accepted.

## Install into `~/.claude`

This repo can become your `~/.claude` directly. Clone the public mirror
somewhere, then run the bundled install script from inside the clone:

```sh
git clone git@github.com:TheVoskamps/global-claude-config-public.git
cd global-claude-config-public
./.global-claude-config/install.sh
```

The HTTPS clone URL works too:

```sh
git clone https://github.com/TheVoskamps/global-claude-config-public.git
```

### What the install script does

In order:

1. **Backs up** any existing `~/.claude/` by moving it aside to a
   timestamped `~/.claude.backup.<timestamp>/` (for example
   `~/.claude.backup.20260524_224418/`).
2. **Installs** the clone by moving the whole clone — including its
   intact `.git` and `origin` pointing at the public mirror — to
   `~/.claude/`. After this, `~/.claude/` is a live git clone you can
   update later with `git -C ~/.claude pull`.
3. **Additively restores** your previous `~/.claude/` files on top of
   the freshly-installed clone, **local wins**: any file you already had
   overwrites the clone's version where they collide, and the clone's
   `.git` is never touched. Your pre-existing files then show as dirty
   in `git -C ~/.claude status` by design.

### Recovery and safety

- The timestamped `~/.claude.backup.<timestamp>/` is always the recovery
  path. The script never deletes it.
- The script is **safe to re-run** and **non-destructive**. If
  `~/.claude/` is already a clone of the public mirror, it reports that
  and exits without moving anything or creating another backup.
- It refuses to run when started from inside `~/.claude/` itself — once
  installed, update the canonical copy with `git -C ~/.claude pull`
  rather than re-running the installer.
