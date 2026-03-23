{
  config,
  lib,
  pkgs,
  ...
}:
{
  # set once, bump carefully
  home.stateVersion = "24.05";

  home.packages = with pkgs; [
    antidote
    asdf-vm
    bat
    delta
    deno
    fzf
    git
    glow
    go
    httpie
    jaq
    jq
    nixfmt
    ripgrep
    shellcheck
    wezterm
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
}
