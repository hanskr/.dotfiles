# .dotfiles

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

<https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#manual-font-installation>

Init
```bash
nix run home-manager/master -- switch --flake github:hanskr/.dotfiles#hanskristiankismul
nix run home-manager/master -- switch --flake github:hanskr/.dotfiles#hans.kristian.kismul@m10s.io
```

Update
```bash
home-manager switch --flake github:hanskr/.dotfiles#hanskristiankismul
home-manager switch --flake github:hanskr/.dotfiles#hans.kristian.kismul@m10s.io
```
