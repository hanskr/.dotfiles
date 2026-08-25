{ pkgs, ... }:
let
  snowflakePkgs = pkgs.extend (final: prev: {
    python3Packages = prev.python3Packages.override {
      overrides = pfinal: pprev: {
        aioboto3 = pprev.aioboto3.overridePythonAttrs {
          doCheck = false;
        };
        # Test suite is broken in the sandbox on Python 3.14: a permission
        # test relies on non-root, and the aio tests error out with
        # "no current event loop in thread 'MainThread'" (asyncio 3.14 change).
        # boto3/botocore are Requires-Dist in the 4.3.0 wheel but nixpkgs lists
        # them as optional, so promote them to real deps or the runtime-deps
        # check fails once nativeCheckInputs are dropped by doCheck = false.
        snowflake-connector-python = pprev.snowflake-connector-python.overridePythonAttrs (old: {
          doCheck = false;
          dependencies = (old.dependencies or []) ++ [ pfinal.boto3 pfinal.botocore ];
        });
      };
    };
  });
in
{
  home.packages = with pkgs; [
    _1password-cli
    acli
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
    nono
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
