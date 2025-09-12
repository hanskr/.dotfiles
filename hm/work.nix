{ pkgs, ... }:
{
  home.packages = with pkgs; [
    kubectl
    kubetail
    sbt
  ];
}
