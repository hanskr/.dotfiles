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
hm purge            # reclaim disk: drop generations older than 30 days
hm purge 7          # keep only the last week
```

`hm` always builds before it prompts, keeping the result as a GC root under
`$XDG_STATE_HOME/hm/`. Declining costs nothing but the wait; accepting later
reuses the build. On a successful switch it offers to commit `flake.lock`
alone — with the version diff as the message — and push.

A `-u` bump only earns its place in the tree by being activated. Decline the
prompt — or hit a failed evaluation, a failed build, or Ctrl-C mid-compile —
and `flake.lock` goes back to what it was, so the bump can never leak into a
later plain `hm #<target>` that said nothing about updating. Run `-u` again to
redo it. A lock you had already edited yourself is left alone.

`hm purge` is the counterweight: every generation is a GC root, so nothing is
ever reclaimed until they are deleted. It covers both profiles under
`$XDG_STATE_HOME/nix/profiles`, hm's own build roots, and `~/.cache/nix`, then
runs `nix-store --gc` and `--optimise`. The current generation and the one
before it are always kept, so rollback survives.

`--optimise` is the long pole: it hashes every file in the store, and a single
nixpkgs checkout is a quarter of a million tiny ones. nix reports nothing while
it does this, so `hm` makes it narrate. Interrupting is free — the hard links it
has already made stay made.

macOS will not let anything — root included — modify a signed `.app` bundle, and
nix drops a path from its database *before* it unlinks it, so a single GUI app in
the store aborts the sweep and leaves behind a directory nix no longer believes
in. `hm purge` pins the bundles as GC roots for the duration instead, so the
collector walks past them; they are the one thing it never reclaims.

If a change ever breaks `hm` itself, home-manager is still there:
```bash
home-manager switch --impure --flake .#work
```
