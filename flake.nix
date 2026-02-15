{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    impermanence.url = "github:nix-community/impermanence";
    impermanence.inputs.nixpkgs.follows = "";
    impermanence.inputs.home-manager.follows = "";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    zls.url = "github:zigtools/zls";
    zls.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "git+https://github.com/hyprwm/Hyprland.git?submodules=1";
    eww.url = "github:elkowar/eww";
    pid-defer.url = "github:Cloudef/pid-defer";
    nix-autoenv.url = "github:Cloudef/nix-autoenv";
    nix-autoenv.inputs.nixpkgs.follows = "nixpkgs";
    bemenu.url = "github:Cloudef/bemenu";
    bemenu.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, impermanence, nix-darwin, ... }: {
    nixosConfigurations = let
      users = {
        root = {
          uid = 0;
          git.name = "Jari Vetoniemi";
          git.email = "jari.vetoniemi@cloudef.pw";
        };
        nix = {
          uid = 1000;
          groups = [ "wheel" "input" "dialout" "adbusers" "corectrl" "docker" "wireshark" ];
          git.name = "Jari Vetoniemi";
          git.email = "jari.vetoniemi@cloudef.pw";
        };
      };
      mainUser = "nix";
    in {
      nixos-linux = let
        cpu = "amd";
      in nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = let
          pid-defer = self.inputs.pid-defer.packages.${system}.default;
        in {
          inherit users mainUser pid-defer;
          inherit (self) inputs;
        };
        modules = [
          ./modules/system/${system}-${cpu}/configuration.nix
          impermanence.nixosModules.impermanence
          ./modules/defaults-linux.nix
          ./modules/hyprland-desktop.nix
          ./modules/steamdeck-experience.nix
          ({...}: {
            programs.hyprland-desktop.enable = true;
            programs.steamdeck-experience.enable = true;
          })
        ];
      };
    };

    darwinConfigurations = let
      users.jari = {
        uid = 501;
        git.name = "Jari Vetoniemi";
        git.email = "jari.vetoniemi@cloudef.pw";
      };
      mainUser = "jari";
    in {
      jv-m1-mbp = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit users mainUser; inherit (self) inputs; };
        modules = [
          ./modules/defaults-darwin.nix
          ({config, pkgs, ...}: {
            nixpkgs.hostPlatform = "aarch64-darwin";
            system.stateVersion = 4;
          })
        ];
      };
    };
  };
}
