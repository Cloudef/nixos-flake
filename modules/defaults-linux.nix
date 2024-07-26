{ config, lib, pkgs, inputs, users, mainUser, ... }:
with lib;
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./defaults.nix
  ];

  nix.gc.dates = "weekly";

  boot.supportedFilesystems = [ "btrfs" "ntfs" "exfat" ];
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
  boot.kernelModules = [ "uinput" "xpadneo" "hid-nintendo" "ecryptfs" ];
  boot.blacklistedKernelModules = [ "xpad" ];
  boot.kernelParams = [ "mitigations=off" "preempt=full" "snd_hda_intel.power_save=0" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ xpadneo ];

  # Allow current console users to add virtual input devices
  services.udev.extraRules = ''
    KERNEL=="uinput", TAG+="uaccess", OPTIONS+="static_node=uinput"
    ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[1-9]", ATTR{queue/scheduler}="kyber"
    ACTION=="add|change", KERNEL=="loop[0-9]", ATTR{queue/scheduler}="kyber"
  '';

  services.fwupd.enable = true;
  services.irqbalance.enable = true;

  services.smartd.enable = true;
  services.fstrim.enable = true;
  services.btrfs.autoScrub = mkIf (config.fileSystems."/".fsType == "btrfs") {
    enable = true;
    fileSystems = [ "/" ];
  };

  services.udisks2.enable = true;

  boot.tmp.useTmpfs = true;

  zramSwap.enable = true;
  zramSwap.memoryPercent = 150;
  zramSwap.algorithm = "zstd";
  boot.kernel.sysctl."vm.swappiness" = 200;
  boot.kernel.sysctl."vm.dirty_background_bytes" = 134217728;
  boot.kernel.sysctl."vm.dirty_background_ratio" = 0;
  boot.kernel.sysctl."vm.dirty_bytes" = 268435456;
  boot.kernel.sysctl."vm.dirty_expire_centisecs" = 3000;
  boot.kernel.sysctl."vm.dirty_ratio" = 0;
  boot.kernel.sysctl."vm.dirtytime_expire_seconds" = 1800;

  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = "schedutil";

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.bluetooth.enable = true;
  hardware.opentabletdriver.enable = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  networking.firewall.enable = false;

  i18n.defaultLocale = "en_US.UTF-8";

  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "btrfs";

  users.mutableUsers = false;
  users.defaultUserShell = pkgs.fish;
  services.getty.autologinUser = mainUser;

  users.users = mapAttrs (user: params: {
    uid = params.uid;
    isNormalUser = true;
    extraGroups = params.groups;
    hashedPasswordFile = "/etc/nixos/secrets/${user}/hashed_password";
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

  services.pipewire.extraConfig.pipewire = {
    context.properties = {
      default.clock.allowed-rates = [ 44100 48000 ];
    };
  };

  services.pipewire.extraConfig.pipewire-pulse = {
    pulse.cmd = [
      { cmd = "load-module"; args = "module-combine-sink"; }
      { cmd = "load-module"; args = "module-switch-on-connect"; }
    ];
  };

  services.pipewire.wireplumber.extraConfig.bluetoothEnhancements = {
    "monitor.bluez.properties" = {
      "bluez5.enable-sbc-xq" = true;
      "bluez5.enable-msbc" = true;
      "bluez5.enable-hw-volume" = true;
      "bluez5.roles" = [ "a2dp_sink" "a2dp_source" ];
    };
    "wireplumber.settings" = {
      "bluetooth.autoswitch-to-headset-profile" = false;
    };
  };

  programs.adb.enable = true;

  programs.gnupg.agent.enable = true;
  programs.gnupg.agent.enableSSHSupport = true;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.PermitRootLogin = "no";

  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;
  services.avahi.publish.enable = true;
  services.avahi.publish.addresses = true;
  services.avahi.publish.domain = true;
  services.avahi.publish.hinfo = true;
  services.avahi.publish.userServices = true;

  fonts.enableDefaultPackages = true;
  fonts.packages = with pkgs; [
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

  programs.wireshark.enable = true;
  programs.wireshark.package = pkgs.wireshark;
  programs.corectrl.enable = true;
  programs.corectrl.gpuOverclock.enable = true;
  programs.gamemode.enable = true;
  programs.gamemode.enableRenice = true;
  programs.gamemode.settings.general.inhibit_screensaver = 0;
  programs.gamemode.settings.general.renice = 10;
  programs.gamemode.settings.gpu.apply_gpu_optimisations = "accept-responsibility";
  programs.gamemode.settings.gpu.gpu_device = 0;
  programs.gamemode.settings.gpu.amd_performance_level = "high";

  environment.systemPackages = with pkgs; [
    sshfs-fuse
    coreutils
    usbutils
    smartmontools
    lshw
    btdu
    lm_sensors
    blueberry
    pavucontrol
    firefox-bin
    obs-studio
    scanmem
    blender
    krita
    webcord
    zathura
    transmission_4-gtk
    powertop
    iotop
    btop
    config.boot.kernelPackages.perf
    perf-tools
    hicolor-icon-theme
    qgnomeplatform
    adwaita-qt
    qgnomeplatform-qt6
    adwaita-qt6
    zenity
    ecryptfs
  ];

  security.pam.enableEcryptfs = true;

  # needed for gtk crap
  programs.dconf.enable = true;
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = "gnome";
  environment.sessionVariables.QT_STYLE_OVERRIDE = "Adwaita-Dark";

  home-manager.users = let
    rootConfig = config;
  in mapAttrs (user: params: { config, pkgs, ... }: {
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

    services.udiskie.enable = true;
    services.udiskie.tray = "never";

    services.easyeffects.enable = true;
    systemd.user.services.shairport-sync = {
      Unit.Description = "Apple AirPlay";
      Unit.After = [ "network.target" "avahi-daemon.service" ];
      Install.WantedBy = [ "multi-user.target" ];
      Service.ExecStart = "${pkgs.shairport-sync}/bin/shairport-sync -v -o pw -a '%u@%H (%%v, %v)'";
      Service.Restart = "on-failure";
    };
  }) (filterAttrs (n: v: n != "root") users);

  environment.sessionVariables.BROWSER = "${pkgs.firefox-bin}/bin/firefox";
}
