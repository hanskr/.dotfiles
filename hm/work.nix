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
    k6
    kubectl
    kubetail
    presenterm
    sbt
    shellcheck
    yaak
  ];
}
