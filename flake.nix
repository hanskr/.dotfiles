{
  description = "Home Manager only (macOS) with separate home/work users & homes";

  inputs = {
    nixpkgs.url = "github:numtide/nixpkgs-unfree/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "aarch64-darwin";
      mkHM =
        {
          extraModules ? [ ],
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          modules = [
            # Pick up username/home from the environment for portability
            {
              home.username = builtins.getEnv "USER";
              home.homeDirectory = builtins.getEnv "HOME";
              xdg.enable = true;
            }
            ./hm/common.nix
          ]
          ++ extraModules;
        };
    in
    {
      homeConfigurations.home = mkHM { extraModules = [ ./hm/home.nix ]; };
      homeConfigurations.work = mkHM { extraModules = [ ./hm/work.nix ]; };
    };
}
