# systemd/

User-level systemd units for this machine. Symlinked into
`~/.config/systemd/user/`, so editing them here edits the live units.

| Unit | Purpose |
|---|---|
| `tailscale-key-expiry.{service,timer}` | Daily warning before the Tailscale node key expires |

## Why the key-expiry timer exists

An expired node key drops the machine off the tailnet, and
`tailscale up --force-reauth` needs a GUI session **at** the machine — there is
no remote fix. The failure is silent right up to the day it locks you out, and
the window is months wide, which is exactly the kind of deadline a human forgets.

A calendar entry would go stale on the next re-auth. This reads the real value
from `tailscale status --json` every day instead, so it stays correct without
being maintained.

## Install after a fresh Fedora install

```bash
mkdir -p ~/.config/systemd/user
ln -sf ~/Workspace/personal/dotfiles/systemd/user/tailscale-key-expiry.service ~/.config/systemd/user/
ln -sf ~/Workspace/personal/dotfiles/systemd/user/tailscale-key-expiry.timer   ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now tailscale-key-expiry.timer
```

## Check it

```bash
systemctl --user list-timers tailscale-key-expiry.timer
TS_KEY_WARN_DAYS=9999 ~/Workspace/personal/dotfiles/bin/tailscale-key-expiry  # force the notification
journalctl --user -t tailscale-key-expiry -n 5
```

Threshold is 30 days by default; override with `TS_KEY_WARN_DAYS`.
