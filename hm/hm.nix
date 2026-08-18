{
  writeShellApplication,
  nvd,
  git,
  coreutils,
  gnused,
  gnugrep,
  gawk,
}:
# `nix` is deliberately absent from runtimeInputs: writeShellApplication
# prepends to $PATH rather than replacing it, so the script picks up the
# Determinate Systems nix that owns the daemon instead of a second copy.
writeShellApplication {
  name = "hm";
  runtimeInputs = [
    nvd
    git
    coreutils
    gnused
    gnugrep
    gawk
  ];
  text = builtins.readFile ./hm.sh;
}
