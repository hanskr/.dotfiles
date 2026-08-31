{ pkgs, ... }:
let
  # Two more tests on top of the long list nixpkgs already skips, both failing
  # for the same reason: Determinate Systems builds under
  # /nix/var/nix/builds/<drv>-<pid>-<rand>, where upstream uses a short
  # /private/tmp path. The first binds a unix socket there and overruns macOS's
  # 104-byte sun_path limit; the second inits a real sandbox there, and nono
  # refuses to grant /nix when its own state root sits underneath it — the same
  # overlap nixpkgs documents for the darwin env_vars tests.
  nono = pkgs.nono.overrideAttrs (old: {
    checkFlags = (old.checkFlags or [ ]) ++ [
      "--skip=proxy_runtime::tests::proxy_credential_capture_backend_exposes_browser_helper_for_open_urls"
      "--skip=why_self_reports_active_profile_deny_before_covering_allow"
    ];
  });

  # Claude Code in the nono sandbox. A package rather than a shell function so
  # that it is a real file on PATH and anything can call it
  nocl = pkgs.writeShellApplication {
    name = "nocl";
    runtimeInputs = [ nono ]; # the let-binding above, not pkgs.nono
    text = builtins.readFile ../dotfiles/bin/nocl;
  };

  # Same, for Codex CLI.
  noco = pkgs.writeShellApplication {
    name = "noco";
    runtimeInputs = [ nono ]; # ditto
    text = builtins.readFile ../dotfiles/bin/noco;
  };

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
    nocl # the let-binding above, not pkgs.nocl
    noco # ditto
    nono # ditto — let bindings win over `with pkgs`
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
