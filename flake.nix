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
      mkHMFlake = conf: home-manager.lib.homeManagerConfiguration.buildFlakePackage conf;
      configs = {
        air = mkHMFlake (mkHM {
          extraModules = [ ./hm/home.nix ];
          user = "hanskristiankismul";
          homeDir = "/Users/hanskristiankismul";
        });
        work = mkHMFlake (mkHM {
          extraModules = [ ./hm/work.nix ];
          user = "hans.kristian.kismul@m10s.io";
          homeDir = "/Users/hans.kristian.kismul@m10s.io";
        });
      };
    in
    {
      # Expose at top level
      homeConfigurations = configs;

      # Expose under packages.<system> so CLI finds activationPackage
      packages.${system}.homeConfigurations = configs;
    };
}
