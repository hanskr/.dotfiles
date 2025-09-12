# .dotfiles

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

<https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#manual-font-installation>

```bash
nix run home-manager/master -- switch --impure --flake github:hanskr/.dotfiles#home
```
