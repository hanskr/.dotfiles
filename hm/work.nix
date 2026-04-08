{ pkgs, ... }:
let
  snowflakePkgs = pkgs.extend (final: prev: {
    python3Packages = prev.python3Packages.override {
      overrides = pfinal: pprev: {
        snowflake-connector-python = pprev.snowflake-connector-python.overridePythonAttrs {
          doCheck = false;
        };
      };
    };
  });
in
{
  home.packages = with pkgs; [
    _1password-cli
    awscli
    gh
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
    (snowflakePkgs.snowflake-cli.overridePythonAttrs (old: {
      doCheck = false;
      propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [ pkgs.python3Packages.keyring ];
    }))
    yaak
  ];
}
