# .dotfiles

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

<https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#manual-font-installation>

Clone it.

Init
```bash
nix run home-manager/master -- switch --impure --flake .#air
```

Update
```bash
home-manager switch --impure --flake .#air
hmu #air

home-manager switch --impure --flake .#work
```
