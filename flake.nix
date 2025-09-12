{
  description = "Home Manager";

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
    }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      mkHM =
        {
          extraModules ? [ ],
        }:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            {
              home.username = builtins.getEnv "USER";
              home.homeDirectory = "/Users/${builtins.getEnv "USER"}";
              xdg.enable = true;
            }
            ./hm/common.nix
          ]
          ++ extraModules;
        };
    in
    {
      homeConfigurations = {
        air = mkHM {
          extraModules = [ ./hm/home.nix ];
        };
        work = mkHM {
          extraModules = [ ./hm/work.nix ];
        };
      };
    };
}
