{
  config,
  lib,
  pkgs,
  ...
}:
{
  # set once, bump carefully
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    antidote
    bat
    delta
    deno
    fzf
    ghostty-bin # macOS: official signed binary; plain `ghostty` is Linux-only
    git
    glow
    (callPackage ./hm.nix { })
    go
    httpie
    jaq
    jq
    mise
    nixfmt
    osmium-tool
    ripgrep
    shellcheck
    viu
  ];

  programs.home-manager.enable = true;

  home.file = {
    ".local/lib/antidote" = {
      source = config.lib.file.mkOutOfStoreSymlink pkgs.antidote;
    };
  };
  home.file.".zshenv".source = ../dotfiles/zsh/.zshenv;
  xdg.configFile."zsh" = {
    source = ../dotfiles/zsh/zsh;
    recursive = true;
  };
  xdg.configFile."git" = {
    source = ../dotfiles/git;
    recursive = true;
  };
  xdg.configFile."wezterm/wezterm.lua" = {
    source = ../dotfiles/wezterm/wezterm.lua;
  };
  xdg.configFile."ghostty/config" = {
    source = ../dotfiles/ghostty/config;
  };

  # Authenticated GitHub fetches for flake inputs; anonymous ones hit the
  # 60/hour API rate limit. The token is kept out of git and the world-readable
  # store: activation writes it next to nix.conf, and `!include` ignores the
  # file if it is missing (e.g. gh not logged in).
  xdg.configFile."nix/nix.conf".text = ''
    !include access-tokens.conf
  '';
  home.activation.nixAccessTokens = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    tokens="${config.xdg.configHome}/nix/access-tokens.conf"
    if [ -n "''${DRY_RUN:-}" ]; then
      verboseEcho "Would write $tokens"
    elif token=$(${pkgs.gh}/bin/gh auth token 2>/dev/null); then
      install -m 600 /dev/null "$tokens"
      printf 'access-tokens = github.com=%s\n' "$token" > "$tokens"
    else
      warnEcho "gh not logged in; skipping $tokens"
    fi
  '';
}
