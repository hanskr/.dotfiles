{ pkgs, ... }:
{
  home.packages = with pkgs; [
    asdf-vm
    kubectl
    kubetail
    sbt
  ];
}
