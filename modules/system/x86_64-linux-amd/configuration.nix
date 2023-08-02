{ config, lib, pkgs, users, mainUser, ... }:
with lib;
{
  imports = [ ./hardware-configuration.nix ];
  fileSystems."/".options = [ "ssd" "compress=zstd" "noatime" ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.extraModulePackages = with config.boot.kernelPackages; [ zenpower ];
  boot.kernelModules = [ "nct6775" "zenpower" ];
  boot.kernelParams = [ "amd_pstate=active" ];
  boot.blacklistedKernelModules = [ "k10temp" ];

  hardware.cpu.amd.updateMicrocode = true;

  console.font = "Lat2-Terminus16";
  console.keyMap = "fi";

  systemd.mounts = [
    {
      what = "jari@jv-m1-mbp.local:";
      where = "/mnt/ssh/jv-m1-mbp";
      type = "fuse.sshfs";
      options = (builtins.concatStringsSep "," [
        # hangs for some reason
        # "debug" "sshfs_debug" "loglevel=debug"
        "_netdev" "nofail" "rw" "noatime" "allow_other"
        "uid=${builtins.toString users."${mainUser}".uid}"
        "gid=${builtins.toString config.ids.gids.users}"
        "umask=0077"
        "IdentitiesOnly=yes" "IdentityFile=/etc/nixos/secrets/root/private_key"
        "StrictHostKeychecking=no" "UserKnownHostsFile=/dev/null"
        "reconnect" "ServerAliveInterval=15" "ServerAliveCountMax=3"
      ]);
      wantedBy = [ "remote-fs.target" ];
    }
  ];

  system.activationScripts.sshfs-fuse-remount-workaround = {
    deps = [ "etc" ];
    text = ''
      name=mnt-ssh-jv\\x2dm1\\x2dmbp.mount
      path=etc/systemd/system/$name
      old_mount=/run/current-system/$path
      new_mount=$systemConfig/$path
      if ! ${pkgs.diffutils}/bin/diff "$old_mount" "$new_mount" >/dev/null 2>&1; then
        ${pkgs.systemd}/bin/systemctl stop "$name"
      fi
      '';
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
