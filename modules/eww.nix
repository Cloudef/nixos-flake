{ config, lib, pkgs, inputs, ... }:
with lib;
let
  cfg = config.programs.eww;
in {
  options.programs.eww = {
    enable = mkEnableOption (mdDoc "Eww");

    package = mkOption {
      type = types.package;
      default = pkgs.eww-wayland;
      defaultText = literalExpression "pkgs.eww";
      description = "The Eww package to install.";
    };

    finalPackage = let
      # https://github.com/elkowar/eww/issues/750
      wrapper = pkgs.writeScriptBin "eww" ''
        XDG_CACHE_HOME=/tmp ${cfg.package}/bin/eww --config /etc/xdg/eww "$@"
        ${pkgs.coreutils}/bin/ln -sf /dev/null /tmp/eww_*.log 2> /dev/null
        '';
    in mkOption {
      type = types.package;
      readOnly = true;
      default = wrapper;
      description = "The wrapped package that reads configuration from /etc/xdg/eww .";
    };

    yuck = mkOption {
      type = types.lines;
      default = "";
      description = mdDoc "Yuck configuration.";
    };

    scss = mkOption {
      type = types.lines;
      default = "";
      description = mdDoc "Scss configuration.";
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.overlays = [
      inputs.rust-overlay.overlays.default
      inputs.eww.overlays.default
    ];
    environment.systemPackages = [ cfg.finalPackage ];
    environment.etc."xdg/eww/eww.yuck".text = cfg.yuck;
    environment.etc."xdg/eww/eww.scss".text = cfg.scss;
  };
}
