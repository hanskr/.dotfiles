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
    bat
    delta
    deno
    fzf
    git
    glow
    httpie
    jq
    ripgrep
    wezterm
  ];

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
