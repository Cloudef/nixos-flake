{ config, lib, pkgs, inputs, users, mainUser, ... }:
with lib;
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./defaults.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_xanmod;
  boot.kernelModules = [ "uinput" "xpadneo" "hid-nintendo" "digimend" ];
  boot.kernelParams = [ "mitigations=off" ];
  boot.extraModulePackages = [
    config.boot.kernelPackages.xpadneo
    config.boot.kernelPackages.hid-nintendo
    config.boot.kernelPackages.digimend
  ];

  # Allow current console users to add virtual input devices
  services.udev.extraRules = ''KERNEL=="uinput", TAG+="uaccess", OPTIONS+="static_node=uinput"'';

  services.fwupd.enable = true;
  services.irqbalance.enable = true;

  services.fstrim.enable = true;
  services.btrfs.autoScrub = mkIf (config.fileSystems."/".fsType == "btrfs") {
    enable = true;
    fileSystems = [ "/" ];
  };

  zramSwap.enable = true;
  zramSwap.algorithm = "zstd";

  powerManagement.cpuFreqGovernor = "schedutil";

  hardware.opengl.enable = true;
  hardware.opengl.driSupport = true;
  hardware.opengl.driSupport32Bit = true; # X86 specific ?
  hardware.bluetooth.enable = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  networking.firewall.enable = false;

  i18n.defaultLocale = "en_US.UTF-8";

  users.mutableUsers = false;
  users.defaultUserShell = pkgs.fish;
  programs.fish.enable = true;
  services.getty.autologinUser = mainUser;

  users.users = mapAttrs (user: params: {
    uid = params.uid;
    isNormalUser = true;
    extraGroups = params.groups;
    passwordFile = "/etc/nixos/secrets/${user}/hashed_password";
  }) (filterAttrs (n: v: n != "root") users);

  # For now all my setups are single user, in any case it would be nicer if user had parameter
  # to indicate passwordless sudo, or perhaps optional commands array in each user
  security.sudo.extraRules = [
    {
      users = [ mainUser ]; # mapAttrsToList (user: _: user) (filterAttrs (n: v: n != "root") users);
      commands = [
        { command = "ALL"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  services.blueman.enable = true;

  security.rtkit.enable = true;
  services.pipewire.enable = true;
  services.pipewire.alsa.enable = true;
  services.pipewire.pulse.enable = true;
  services.pipewire.jack.enable = true;
  services.pipewire.wireplumber.enable = true;

  environment.etc."wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
    bluez_monitor.properties = {
      ["bluez5.enable-sbc-xq"] = true,
      ["bluez5.enable-msbc"] = true,
      ["bluez5.enable-hw-volume"] = true,
      ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
    }
    '';

  environment.etc."pipewire/pipewire.conf.d/92-low-latency.conf".text = ''
    context.properties = {
      default.clock.quantum = 128
      default.clock.min-quantum = 128
      default.clock.max-quantum = 128
    }
    '';

  programs.gnupg.agent.enable = true;
  programs.gnupg.agent.enableSSHSupport = true;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.PermitRootLogin = "no";

  services.avahi.enable = true;
  services.avahi.nssmdns = true;
  services.avahi.publish.enable = true;
  services.avahi.publish.addresses = true;
  services.avahi.publish.domain = true;
  services.avahi.publish.hinfo = true;
  services.avahi.publish.userServices = true;

  fonts.enableDefaultFonts = true;
  fonts.fonts = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
  ];

  # This part is hw dependant really, move if more than 1 linux machine in future
  fonts.fontconfig.enable = true;
  fonts.fontconfig.antialias = true;
  fonts.fontconfig.hinting.enable = true;
  fonts.fontconfig.hinting.style = "slight";
  fonts.fontconfig.hinting.autohint = true;
  fonts.fontconfig.subpixel.rgba = "rgb";
  fonts.fontconfig.subpixel.lcdfilter = "default";

  programs.gamemode.enable = true;
  programs.gamemode.enableRenice = true;
  programs.gamemode.settings.general.inhibit_screensaver = 0;
  programs.gamemode.settings.general.renice = 10;
  programs.gamemode.settings.gpu.apply_gpu_optimisations = "accept-responsibility";
  programs.gamemode.settings.gpu.gpu_device = 0;
  programs.gamemode.settings.gpu.amd_performance_level = "high";

  environment.systemPackages = with pkgs; [
    sshfs-fuse
    git
    coreutils
    moreutils
    lshw
    lm_sensors
    blueberry
    pavucontrol
    firefox
    obs-studio
    scanmem
    blender
    krita
    webcord-vencord
    zathura
    powertop
    iotop
    config.boot.kernelPackages.perf
    perf-tools
    hicolor-icon-theme
    qgnomeplatform
    adwaita-qt
    qgnomeplatform-qt6
    adwaita-qt6
  ];

  # needed for gtk crap
  programs.dconf.enable = true;
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = "gnome";
  environment.sessionVariables.QT_STYLE_OVERRIDE = "Adwaita-Dark";

  home-manager.users = let
    rootConfig = config;
  in mapAttrs (user: params: { config, pkgs, ... }: {
    services.easyeffects.enable = true;
    gtk.enable = rootConfig.programs.dconf.enable;
    gtk.iconTheme.name = "Papirus-Dark";
    gtk.iconTheme.package = pkgs.papirus-icon-theme;
    gtk.theme.name = "Adwaita";
    gtk.cursorTheme.name = pkgs.phinger-cursors.pname;
    gtk.cursorTheme.package = pkgs.phinger-cursors;
    gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
    i18n.inputMethod.enabled = "fcitx5";
    i18n.inputMethod.fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
    ];
  }) (filterAttrs (n: v: n != "root") users);

  environment.sessionVariables.BROWSER = "${pkgs.firefox}/bin/firefox";
}
