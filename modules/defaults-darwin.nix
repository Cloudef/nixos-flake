{ config, lib, pkgs, inputs, users, mainUser, ... }:
# TODO: install alacritty.info (currently done manually)
#       sudo tic -e alacritty,alacritty-direct alacritty.info
#       https://raw.githubusercontent.com/alacritty/alacritty/master/extra/alacritty.info
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

  system.primaryUser = mainUser;

  nix.enable = true;
  security.pam.services.sudo_local.touchIdAuth = true;
  nix.gc.interval = { Weekday = 0; Hour = 0; Minute = 0; };

  # neovim.nix aliases do not seem to apply, so fix here
  programs.fish.interactiveShellInit = ''
    # TODO: we probably do not need this as nixpkgs already has flutter
    set PATH "$PATH:$HOME/dev/flutter/bin"
    '';

  system.defaults = {
    dock.autohide = true;
    dock.orientation = "left";
    finder.AppleShowAllExtensions = true;
    finder._FXShowPosixPathInTitle = true;
    finder.FXEnableExtensionChangeWarning = false;
    NSGlobalDomain."com.apple.swipescrolldirection" = false;
    screencapture.location = "/tmp";
  };

  system.defaults.CustomUserPreferences = {
    "com.apple.finder" = {
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = true;
      ShowMountedServersOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
      _FXSortFoldersFirst = true;
      # When performing a search, search the current folder by default
      FXDefaultSearchScope = "SCcf";
    };
    "com.apple.desktopservices" = {
      # Avoid creating .DS_Store files on network or USB volumes
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
    };
    "com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false;
    };
    "com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;
      ScheduleFrequency = 1;
      AutomaticDownload = 1;
      CriticalUpdateInstall = 0;
    };
    "com.apple.ImageCapture".disableHotPlug = true;
    "com.apple.commerce".AutoUpdate = true;
  };

  environment.variables.JAVA_HOME = "/Applications/Android Studio.app/Contents/jre/Contents/Home";
}
