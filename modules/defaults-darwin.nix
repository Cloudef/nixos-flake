{ config, lib, pkgs, inputs, users, ... }:
with lib;
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    ./defaults.nix
  ];

  environment.shells = with pkgs; [ fish ];
  users.users = mapAttrs (user: params: {
    uid = params.uid;
    home = "/Users/${user}";
  }) (filterAttrs (n: v: n != "root") users);

  security.pam.enableSudoTouchIdAuth = true;
  services.nix-daemon.enable = true;
  nix.gc.interval = { Weekday = 0; Hour = 0; Minute = 0; };

  # neovim.nix aliases do not seem to apply, so fix here
  programs.fish.interactiveShellInit = ''
    alias vim="nvim"
    # TODO: we probably do not need this as nixpkgs already has flutter
    PATH="$PATH:$HOME/dev/flutter/bin"
    '';

  system.defaults = {
    dock.autohide = true;
    dock.orientation = "left";
    finder.AppleShowAllExtensions = true;
    finder._FXShowPosixPathInTitle = true;
    finder.FXEnableExtensionChangeWarning = false;
    NSGlobalDomain._HIHideMenuBar = true;
    NSGlobalDomain."com.apple.swipescrolldirection" = false;
    screencapture.location = "/tmp";
  };

  environment.variables.JAVA_HOME = "/Applications/Android Studio.app/Contents/jre/Contents/Home";

  nixpkgs.overlays = [(final: prev: {
    # TODO: add to nixpkgs upstream
    bemenu = prev.bemenu.overrideAttrs (oldAttrs: {
      nativeBuildInputs = with pkgs; [ pkg-config scdoc ];
      buildInputs = with pkgs; [ ncurses ];

      postPatch = ''
        substituteInPlace GNUmakefile --replace '-soname' '-install_name'
        '';

      makeFlags = ["PREFIX=$(out)"];
      buildFlags = ["PREFIX=$(out)" "clients" "curses"];

      # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/setup-hooks/fix-darwin-dylib-names.sh
      # ^ does not handle .so files
      postInstall = ''
        so="$(find "$out/lib" -name "libbemenu.so.[0-9]" -print -quit)"
        for f in "$out/bin/"*; do
            install_name_tool -change "$(basename $so)" "$so" $f
        done
        '';

      meta = {
        homepage = "https://github.com/Cloudef/bemenu";
        description = "Dynamic menu library and client program inspired by dmenu";
        license = licenses.gpl3Plus;
        platforms = with platforms; darwin;
      };
    });
  })];
}
