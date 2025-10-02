{ pkgs, ... }:
{
  home.packages = with pkgs; [
    asdf-vm
    (google-cloud-sdk.withExtraComponents (
      with google-cloud-sdk.components;
      [
        gke-gcloud-auth-plugin
      ]
    ))
    k6
    kubectl
    kubetail
    nodejs_24
    sbt
  ];
}
