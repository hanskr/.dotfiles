# .dotfiles

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

<https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#manual-font-installation>

Init
```bash
nix run home-manager/master -- switch --impure --flake github:hanskr/.dotfiles#air
nix run home-manager/master -- switch --impure --flake github:hanskr/.dotfiles#work
```

Update
```bash
home-manager switch --impure --flake github:hanskr/.dotfiles#air
home-manager switch --impure --flake github:hanskr/.dotfiles#work
```
