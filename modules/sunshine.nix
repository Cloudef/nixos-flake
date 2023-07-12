{ config, lib, pkgs, inputs, ... }:
with lib;
let
  cfg = config.programs.sunshine;
in {
  imports = [ inputs.home-manager.nixosModules.home-manager ];
  disabledModules = ["programs/sunshine.nix"];

  options.programs.sunshine = {
    enable = mkEnableOption (mdDoc "sunshine");

    users = mkOption {
      type = types.listOf types.str;
      default = [];
      description = mdDoc ''
        Users for which sunshine will be available for.
        '';
    };

    apps = mkOption {
      type = types.listOf types.attrs;
      default = [ { name = "Desktop"; } ];
      description = mdDoc ''
        Apps that can be launched through sunshine.
        '';
    };

    fps = mkOption {
      type = types.listOf types.int;
      default = [ 30 60 ];

    };

    min_threads = mkOption {
      type = types.int;
      default = 4;
    };

    resolutions = mkOption {
      type = types.listOf types.str;
      default = [ "640x480" "768x576" "1280x720" "1920x1080" "2560x1440" ];
    };

    encoder = mkOption {
      type = types.str;
      default = "software";
    };

    upnp = mkOption {
      type = types.bool;
      default = true;
    };

    scope = mkOption {
      type = types.str;
      default = "lan";
    };

    web_ui_scope = mkOption {
      type = types.str;
      default = "lan";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = mdDoc ''
        Extra configuration text appended to {file}`sunshine.conf`. Other generated
        options will be prepended.
        '';
    };
  };

  config = mkIf cfg.enable {
    security.wrappers.sunshine = {
      owner = "root"; group = "root";
      capabilities = "cap_sys_admin+p";
      source = "${pkgs.sunshine}/bin/sunshine";
    };

    home-manager.users = let
      rootConfig = config;
    in builtins.listToAttrs (builtins.map (u:
      { name = u; value = {
        systemd.user.services.sunshine = {
          Unit.Description = "Sunshine is a Game stream host for Moonlight.";
          Service.ExecStart = "${rootConfig.security.wrapperDir}/sunshine";
          Install.WantedBy = [ "graphical-session.target" ];
        };

        xdg.configFile."sunshine/sunshine.conf".text = let
          apps = pkgs.writeText "apps.json" ''
            {
              "env": { "PATH": "$(PATH)" },
              "apps": ${builtins.toJSON cfg.apps}
            }
            '';
        in ''
          origin_pin_allowed = ${cfg.scope}
          origin_web_ui_allowed = ${cfg.web_ui_scope}
          upnp = ${if (cfg.upnp) then "on" else "off"}
          file_apps = ${apps}
          encoder = ${cfg.encoder}
          min_threads = ${builtins.toString cfg.min_threads}
          fps = [ ${builtins.toJSON cfg.fps} ]
          resolutions = ${concatStringsSep " " cfg.resolutions}
          '';
      };
    }) cfg.users);
  };
}
