{ config, lib, pkgs, inputs, users, ... }:
with lib;
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./neovim.nix
  ];

  # Sorry Stallman, gotta play em gayms
  nixpkgs.config.allowUnfree = true;

  # Flakes system
  nix.settings.extra-experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.registry = lib.mapAttrs (_: value: { flake = value; }) inputs;
  nix.nixPath = (lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry);
  nix.gc.automatic = lib.mkDefault true;
  nix.gc.options = lib.mkDefault "--delete-older-than 14d";
  nix.gc.dates = lib.mkDefault "weekly";

  # We in Tokyo
  time.timeZone = "Asia/Tokyo";

  # Home stuff that works everywhere
  home-manager.users = let
    rootConfig = config;
  in mapAttrs (user: params: { config, pkgs, ... }: {
    home.stateVersion = rootConfig.system.stateVersion;
    home.file.".ssh/authorized_keys".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/secrets/${user}/authorized_keys";
    home.file.".ssh/id_rsa.pub".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/secrets/${user}/public_key";
    home.file.".ssh/id_rsa".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/secrets/${user}/private_key";
    programs.nix-index.enable = true;
    programs.git.enable = true;
    programs.git.userName = params.git.name;
    programs.git.userEmail = params.git.email;
    programs.git.extraConfig.init.defaultBranch = "master";
    programs.git.extraConfig.safe.directory = "*";
    programs.fish.enable = true;
    programs.fish.interactiveShellInit = ''
      alias ls="ls -lAh --group-directories-first --color=auto"
      alias mv="mv -v"
      alias cp="cp -v"
      alias rm="rm -v"
      alias dev="cd $HOME/dev/personal"
    '';
    home.packages = let
      vimo = pkgs.writeShellApplication {
        name = "vimo";
        runtimeInputs = with pkgs; [ git gnugrep bemenu ];
        text = ''
          read -r gtdir < <(git rev-parse --show-toplevel)
          (cd "$gtdir" && git ls-files) | BEMENU_BACKEND=curses bemenu -i -l 20 -p "vim" --accept-single | while read -r match; do
            $EDITOR "$gtdir/$match"
          done
          '';
      };
    in with pkgs; [
      vimo
      bemenu
      fishPlugins.forgit
      fishPlugins.done
      fishPlugins.grc
      fishPlugins.hydro
      grc
      curl
      tree
      dfc
      ncdu
      btdu
      file
      jaq
      silver-searcher
      htop
      unar
      p7zip
      imagemagick
      ffmpeg
      yt-dlp
      mpv
    ];
  }) users;
}
