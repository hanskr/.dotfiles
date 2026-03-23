{ pkgs, ... }:
{
  home.packages = with pkgs; [
    _1password-cli
    awscli
    gnupg
    (google-cloud-sdk.withExtraComponents (
      with google-cloud-sdk.components;
      [
        gke-gcloud-auth-plugin
      ]
    ))
    humioctl
    k6
    kubectl
    kubetail
    mermaid-cli
    postgresql
    presenterm
    sbt
    (snowflake-cli.overridePythonAttrs (old: {
      doCheck = false;
      propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [ pkgs.python3Packages.keyring ];
    }))
    yaak
  ];
}
