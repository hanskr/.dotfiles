{ pkgs, ... }:
{
  home.packages = with pkgs; [
    asdf-vm
    k6
    kubectl
    kubetail
    sbt
  ];
}
