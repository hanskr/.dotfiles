# .dotfiles

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

<https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#manual-font-installation>

Clone it.

Init — bootstrap only. `hm` is installed *by* home-manager, so the first
switch on a new machine has to go through home-manager directly:
```bash
nix run home-manager/master -- switch --impure --flake .#air
```

After that, use `hm` (`hm/hm.sh`):
```bash
hm #air             # build, show what changes, ask before applying
hm #work -u         # 'nix flake update' first — the weekly bump
hm list             # recent generations, with what changed in each
hm diff 118 120     # version diff between two generations
hm rollback         # back to the previous one
hm rollback 118     # back to a specific one
```

`hm` always builds before it prompts, keeping the result as a GC root under
`$XDG_STATE_HOME/hm/`. Declining costs nothing but the wait; accepting later
reuses the build. On a successful switch it offers to commit `flake.lock`
alone — with the version diff as the message — and push.

If a change ever breaks `hm` itself, home-manager is still there:
```bash
home-manager switch --impure --flake .#work
```
