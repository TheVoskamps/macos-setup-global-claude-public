# `.global-claude-config/` -- Template Payload Directory

This directory ships template files ("payloads") that skills use to
bootstrap configuration in target repos. Each skill owns a
subdirectory named after the skill; the skill reads its templates from
there at runtime.

The directory is part of the `global-claude-config` source repo and
reaches end users via the public mirror. After installation (see
`install.sh` in this directory), the payloads live at
`~/.claude/global-claude-config/<skill-name>/...`.

## Directory layout

```text
.global-claude-config/
  README.md              # this file
  install.sh             # self-contained installer for the mirror clone
  <skill-name>/          # per-skill payload directory
    <template-file>      # one or more template files with placeholders
    ...
```

Each `<skill-name>/` subdirectory mirrors the skill's name under
`skills/` (e.g. `repo-public-mirror-setup`, `pr-automation-setup`).

## Placeholder syntax

Template files use **double-underscore delimited UPPER_SNAKE_CASE**
names as placeholders:

```text
__PLACEHOLDER_NAME__
```

Concrete examples:

| Placeholder | Meaning |
| --- | --- |
| `__GH_ORG__` | GitHub organization or user that owns the repo |
| `__GH_REPO__` | Repository name (without the org prefix) |
| `__DEFAULT_BRANCH__` | Default branch of the target repo |
| `__APP_NAME__` | Name of the GitHub App used for automation |
| `__APP_ID__` | Numeric ID of the GitHub App |

Skills may define additional placeholders as needed. Every placeholder
a template uses must be documented in a comment block at the top of the
template file or in the skill's `SKILL.md`.

### Rules for placeholder names

1. Must match the regex `__[A-Z][A-Z0-9_]*__` (leading double
   underscore, trailing double underscore, uppercase alphanumeric
   plus underscore in between).
2. Must be unique within a template file.
3. Must not collide with a different meaning across skills. If two
   skills need the same concept, use the same placeholder name.

## Discovering placeholders in a template

A skill discovers which placeholders a template needs by scanning for
the pattern:

```bash
grep -oE '__[A-Z][A-Z0-9_]*__' <template-file> | sort -u
```

This returns the deduplicated list of placeholder names the template
expects. The skill resolves each one before rendering.

## Resolving placeholder values

Values are resolved in this order (first match wins):

1. **Inferred from the environment** -- values the skill can determine
   automatically from `gh` and `git` in the target repo:

   | Placeholder | Inference command |
   | --- | --- |
   | `__GH_ORG__` | `gh repo view --json owner -q .owner.login` |
   | `__GH_REPO__` | `gh repo view --json name -q .name` |
   | `__DEFAULT_BRANCH__` | `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` |

2. **Passed by the caller** -- the skill's `SKILL.md` may define
   inputs that map to specific placeholders (e.g. `--app-name` maps
   to `__APP_NAME__`). The skill resolves these from its own input
   processing.

3. **Prompted from the user** -- if a placeholder cannot be inferred
   or passed, the skill asks the user via `AskUserQuestion` before
   proceeding. The prompt names the placeholder and explains what
   value is expected.

A skill must never render a template with unresolved placeholders. If
any placeholder remains after exhausting all three resolution steps,
the skill aborts with:

> Unresolved placeholder `__NAME__` in template
> `<skill-name>/<file>`. Pass a value or add inference logic.

## Rendering a template

The render step is a simple string substitution:

1. Read the template file from
   `~/.claude/global-claude-config/<skill-name>/<file>`.
2. For each placeholder found by the discovery scan, replace every
   occurrence of `__PLACEHOLDER_NAME__` with the resolved value.
3. Write the result to the target path in the user's repo.

Skills perform this substitution in whatever language or tool is
natural for the context (shell `sed`, inline string replacement in a
skill's prose instructions, etc.). The mechanism is deliberately
simple -- no conditionals, no loops, no escaping beyond what the
target file format requires.

### Rendering in shell (reference recipe)

```bash
rendered="$(cat "$template_path")"
rendered="${rendered//__GH_ORG__/$gh_org}"
rendered="${rendered//__GH_REPO__/$gh_repo}"
rendered="${rendered//__DEFAULT_BRANCH__/$default_branch}"
# ... one substitution per placeholder
echo "$rendered" > "$target_path"
```

For templates consumed by Claude skills (prose-defined, not
executable), the skill reads the template, performs the substitutions
inline, and writes the output using the `Write` tool.

## Runtime existence check

Every skill that consumes payloads checks for its subdirectory at the
start of its run:

```text
~/.claude/global-claude-config/<skill-name>/
```

If the directory is missing, the skill aborts with:

> Payload directory `~/.claude/global-claude-config/<skill-name>/`
> not found. Install via the public mirror first:
>
> ```text
> git clone <mirror-url>
> cd <mirror-repo>
> ./.global-claude-config/install.sh
> ```

This ensures that mirror-installed users get a clear error pointing at
the install path rather than a confusing file-not-found failure
mid-skill.

## Mirror survival

This directory is listed in `.github/public-mirror/paths.allowlist`.
Without that entry, the mirror filter would strip payloads and every
skill's runtime existence check would fail for mirror-installed users.

When adding a new skill payload subdirectory, no allowlist change is
needed -- the top-level `.global-claude-config/` entry covers all
contents recursively.
