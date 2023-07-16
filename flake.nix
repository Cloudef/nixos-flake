{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, hyprland, ... }: {
    nixosConfigurations = let
      users.root = {
        uid = 0;
        git.name = "Jari Vetoniemi";
        git.email = "jari.vetoniemi@cloudef.pw";
      };

      users.nix = {
        uid = 1000;
        groups = [ "wheel" ];
        git.name = "Jari Vetoniemi";
        git.email = "jari.vetoniemi@cloudef.pw";
      };

      mainUser = "nix";
    in {
      nixos-linux = let
        cpu = "amd";
      in nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = { inherit users mainUser; inherit (self) inputs; };
        modules = [
          ./modules/system/${system}-${cpu}/configuration.nix
          ./modules/defaults-linux.nix
          ./modules/hyprland-desktop.nix
          ./modules/steamdeck-experience.nix
          ./modules/sunshine.nix
          ({config, pkgs, ...}: {
            programs.hyprland-desktop.enable = true;
            programs.steamdeck-experience.enable = true;
            programs.sunshine.enable = true;
            programs.sunshine.users = [ "nix" ];
            programs.sunshine.apps = [
              { name = "Desktop"; image-path = "${pkgs.sunshine}/assets/desktop-alt.png"; }
              { name = "Steam"; cmd = "${pkgs.hyprland}/bin/hyprctl dispatch exec steam-gamescope"; image-path = "${pkgs.sunshine}/assets/steam.png"; }
            ];
          })
        ];
      };
    };
  };
}
