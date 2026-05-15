# Credential Surfaces Are User-Owned

When a git, ssh, gpg, or AWS command fails with an authentication
error -- SSH `Permission denied (publickey)`, SSO `Token has
expired`, gpg-agent unlocked-key timeout, etc. -- the credential
surface (SSH agent, SSO cache, GPG agent, keyring) is the user's.

## Required behavior on auth failure

1. State the failure plainly.
2. Stop. Do not retry, do not investigate.
3. Wait for the user. They are likely mid-task in another
   window: unlocking a key, approving MFA on a phone,
   typing a passphrase, dealing with a browser flow.
4. When the user tells you to retry, re-run the exact
   original command verbatim.
5. If the same command fails a second time after the
   retry, surface that and stop again. Do not escalate
   to different tools, different auth paths, or different
   profiles without being asked.

## Forbidden tools and probes

Do NOT, on your own initiative:

- Run `ssh-add`, `ssh-agent`, `keychain`, `security`,
  `gpg-connect-agent`, or any tool that inspects or
  manipulates the user's credential agent.
- Run `aws sso login` to refresh an expired SSO token.
  Report the expired token and wait for the user to
  refresh it.
- Read or list files under `~/.ssh/`, `~/.aws/sso/cache/`,
  `~/.gnupg/`, or `~/Library/Keychains/`.
- Switch from SSH to HTTPS (or vice versa) for git
  remotes, swap AWS profiles, or rewrite remote URLs.
- Loop a failing command with `sleep` in the hope the
  agent comes back.

## Why

SSH, SSO, and GPG agent state is owned by the user, not
by me. The user is usually mid-task on something else when
auth fails. Probing credential surfaces also risks
accidentally caching, exporting, or logging credentials
that should stay in the agent.

The right behavior is patience and a clean retry on
prompt, not investigation.
