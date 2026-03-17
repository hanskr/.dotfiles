{ pkgs, ... }:
{
  home.packages = with pkgs; [
    _1password-cli
    asdf-vm
    awscli
    gnupg
    (google-cloud-sdk.withExtraComponents (
      with google-cloud-sdk.components;
      [
        gke-gcloud-auth-plugin
      ]
    ))
    jaq
    go
    humioctl
    k6
    kubectl
    kubetail
    mermaid-cli
    postgresql
    presenterm
    sbt
    shellcheck
    yaak
  ];
}
