# mac/

Scripts that run on the **work macOS machine**, not on this Fedora box.

Kept separate so they are never mistaken for local tooling: `zsh/functions/` is
this machine's, and nothing in here should ever be symlinked onto `$PATH` here —
`stat -f`, `pmset`, `launchctl` and `security` are all macOS-only.

| File | Purpose |
|---|---|
| `preflight` | Check and arm the Mac before leaving the desk — see `guides/remote-access-runbook.md` §8 |

## Deploying to the Mac

```bash
macup    # confirm the Mac is awake first

ssh mac-cmp-file 'mkdir -p ~/bin && grep -q "HOME/bin" ~/.zshenv \
  || echo "export PATH=\"\$HOME/bin:\$PATH\"" >> ~/.zshenv'
scp mac/preflight mac-cmp-file:~/bin/preflight
ssh mac-cmp-file 'chmod +x ~/bin/preflight && ~/bin/preflight'
```

`.zshenv`, not `.zshrc`: `ssh host <cmd>` is a non-interactive session and zsh
reads `.zshenv` only.

Script comments are English to match the rest of the repo; the status output the
script prints stays Vietnamese to match the runbook it belongs to.
