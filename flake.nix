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
          user, 
          homeDir,
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          modules = [
            # Pick up username/home from the environment for portability
            {
              home.username = user;
              home.homeDirectory = homeDir;
              xdg.enable = true;
            }
            ./hm/common.nix
          ]
          ++ extraModules;
        };
    in
    {
      homeConfigurations.home = mkHM {
        extraModules = [ ./hm/home.nix ];
        user = "hanskristiankismul";
        homeDir = "/Users/hanskristiankismul";
      };
      homeConfigurations.work = mkHM {
        extraModules = [ ./hm/work.nix ];
        user = "hans.kristian.kismulm10s.io";
        homeDir = "/Users/hans.kristian.kismulm10s.io";
      };
    };
}
