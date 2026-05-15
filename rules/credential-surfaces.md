# Credential Surfaces Are User-Owned

The user's credential agents (SSH agent, SSO token cache, GPG
agent, system keychain) are the user's. Don't probe them. Don't
manipulate them. But running a normal command that prompts for
credentials is fine -- that is no different from any other
command that blocks on I/O.

## What's allowed

Commands whose normal flow prompts the user for credentials are
fine to run. The harness surfaces the prompt; the user responds
on their own time; the command continues:

- `git push`, `git pull`, `git fetch` (may prompt for SSH key
  passphrase or HTTPS credential helper).
- `aws sso login --profile <name>` (opens a browser for SSO).
- `gh auth login` (opens a browser for GitHub).
- `kubectl` operations that hit an EKS cluster and require
  fresh IAM credentials.

Running these is no different from running any other command
that might block on I/O. If the user is slow to respond, wait.

## What's forbidden

Do NOT, on your own initiative, run tools that **inspect or
manipulate the user's credential agent state**:

- `ssh-add`, `ssh-agent`, `keychain`.
- macOS `security` CLI against the keychain.
- `gpg-connect-agent`, `gpgconf`.
- Reading or listing `~/.ssh/`, `~/.aws/sso/cache/`,
  `~/.gnupg/`, or `~/Library/Keychains/`.
- Switching from SSH to HTTPS (or vice versa) for git remotes,
  swapping AWS profiles, or rewriting remote URLs to dodge an
  auth failure.
- Looping a failing command with `sleep` in the hope the agent
  comes back.

These are agent introspection, not normal command execution.

## On auth failure

When a normal command fails with an auth error:

1. State the failure plainly.
2. If the failure is **expired or missing credentials** and the
   fix is a single credential-prompting command from "What's
   allowed" above, run that command. Wait for the user to
   complete the browser flow or unlock prompt.
3. If the failure is **agent-state opaque** -- e.g. SSH
   `Permission denied (publickey)` with no clear single-command
   fix -- stop. Report the failure. Wait for the user to deal
   with it. When told to retry, re-run the exact original
   command verbatim.
4. Never escalate to forbidden tools from "What's forbidden".
   If the obvious credential-prompting command doesn't resolve
   the failure, stop and ask the user.

## Why

The agent's state is the user's. Probing or manipulating it
risks accidentally caching, exporting, or logging credentials
that should stay in the agent. Running commands that happen to
trigger an OS-level credential prompt is a different category
entirely -- those commands are the normal way the user supplies
credentials, and waiting for the user to respond is the same
patience required by any blocking I/O.
