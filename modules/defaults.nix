{ config, lib, pkgs, inputs, users, ... }:
with lib;
{
  imports = [ ./neovim.nix ];

  # Override bemenu
  nixpkgs.overlays = [(final: prev: {
    bemenu = inputs.bemenu.packages.${pkgs.system}.default;
  })];

  # Sorry Stallman, gotta play em gayms
  nixpkgs.config.allowUnfree = true;

  # Flakes system
  nix.settings.extra-experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.registry = lib.mapAttrs (_: value: { flake = value; }) inputs;
  nix.nixPath = (lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry);
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 14d";

  # Some binary caches
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "https://aws-lambda-rust.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "aws-lambda-rust.cachix.org-1:bnY1QkUrQuSIHHfc3TJ1KL6xLvjQEKyHuQgweJl57RY="
  ];

  # We in Tokyo
  time.timeZone = "Asia/Tokyo";

  # FIISH
  programs.fish.enable = true;

  # XXX: sessionVariables is not available on nix-darwin
  environment.variables.BEMENU_OPTS = "-H 32 --cw 2 --ch 2";

  # Home stuff that works everywhere
  home-manager.users = let
    prefix = if (pkgs.stdenv.isLinux) then "/home" else "/Users";
  in mapAttrs (user: params: { config, pkgs, ... }: let
    homeDir = "${prefix}/${user}";
  in {
    home.stateVersion = "23.05";
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
      set -gx NIX_AUTOENV_AUTO 1
      source (nix-autoenv fish-setup | psub)
      alias ls="${pkgs.coreutils}/bin/ls -lAh --group-directories-first --color=auto"
      alias mv="mv -v"
      alias cp="cp -v"
      alias rm="rm -v"
      alias dev="cd $HOME/dev"
      '';
    services.syncthing.enable = true;
    services.syncthing.extraOptions = [ "--home=${homeDir}/misc/syncthing" ];
    home.file."misc/.keep".text = "";
  }) users;

  fonts = let
    packages = with pkgs; [
      nerdfonts
    ];
  in if (pkgs.stdenv.isLinux) then {
    packages = packages;
  } else {
    # darwin hasn't yet migrated to the new syntax
    fontDir.enable = true;
    fonts = packages;
  };

  environment.systemPackages = let
    vimo = pkgs.writeShellApplication {
      name = "vimo";
      runtimeInputs = with pkgs; [ git gnugrep bemenu ];
      text = ''
        read -r gtdir < <(git rev-parse --show-toplevel)
        (cd "$gtdir" && git ls-files) | BEMENU_BACKEND=curses bemenu -i -l 20 -p "vim" --ifne | while read -r match; do
          $EDITOR "$gtdir/$match"
        done
        '';
    };

    nrun = pkgs.writeShellApplication {
      name = "nrun";
      runtimeInputs = with pkgs; [ coreutils gnused bemenu ];
      text = ''
        pkg="$(nix-locate --minimal --top-level '/bin/' | grep -v '^_' | sed 's/\.out$//' | sort -u | bemenu)"
        NIXPKGS_ALLOW_UNFREE=1 nix run --impure "nixpkgs#$pkg" -- "$@"
        '';
    };

    psmenu = pkgs.writeShellApplication {
      name = "psmenu";
      runtimeInputs = with pkgs; [ procps bemenu ];
      text = ''
        ps --no-headers -a --sort "-%cpu" -o "pid,%cpu,%mem,args" | BEMENU_BACKEND=curses bemenu -i -l 20 -p "psmenu" --ifne | while read -r line; do
          IFS=" " read -r pid _ <<<"$line"
          printf "%s\n" "$pid"
        done
        '';
    };
  in with pkgs; [
    inputs.nix-autoenv.packages.${system}.default
    vimo
    nrun
    psmenu
    bemenu
    fishPlugins.forgit
    fishPlugins.done
    fishPlugins.grc
    fishPlugins.hydro
    moreutils
    git
    grc
    curl
    tree
    dfc
    ncdu
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
    nix-tree
  ];
}
