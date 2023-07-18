{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.alacritty;
  yamlFormat = pkgs.formats.yaml { };
in {
  disabledModules = ["programs/alacritty.nix"];

  options.programs.alacritty = {
    enable = mkEnableOption (mdDoc "Alacritty");

    package = mkOption {
      type = types.package;
      default = pkgs.alacritty;
      defaultText = literalExpression "pkgs.alacritty";
      description = "The Alacritty package to install.";
    };

    finalPackage = let
      wrapped = pkgs.writeScriptBin "alacritty" ''
        ${cfg.package}/bin/alacritty --config-file /etc/xdg/alacritty.yml "$@"
        '';
    in mkOption {
      type = types.package;
      readOnly = true;
      default = wrapped;
      description = "The wrapped package that reads configuration from /etc/xdg/alacritty.yml .";
    };

    settings = mkOption {
      type = yamlFormat.type;
      default = {
        live_config_reload = true;
        window.padding = { x = 4; y = 2; };
        window.dynamic_padding = true;
        window.decorations = "none";
        scrolling.history = 65536;
        colors.primary.background = "#121212";
        colors.primary.foreground = "#cacaca";
        colors.normal.black = "#1c1c1c";
        colors.bright.black = "#4d4d4d";
        colors.normal.red = "#d81860";
        colors.bright.red = "#f00060";
        colors.normal.green = "#b7ce42";
        colors.bright.green = "#bde077";
        colors.normal.yellow = "#fea63c";
        colors.bright.yellow = "#ffe863";
        colors.normal.blue = "#66aabb";
        colors.bright.blue = "#aaccbb";
        colors.normal.magneta = "#b7416e";
        colors.bright.magneta = "#bb4466";
        colors.normal.cyan = "#5e7175";
        colors.bright.cyan = "#a3babf";
        colors.normal.white = "#ddeedd";
        colors.bright.white = "#6c887a";
      };
      example = literalExpression ''
        {
          window.dimensions = {
            lines = 3;
            columns = 200;
          };
          key_bindings = [
            {
              key = "K";
              mods = "Control";
              chars = "\\x0c";
            }
          ];
        }
      '';
      description = ''
        Configuration written to
        <filename>/etc/xdg/alacritty.yml</filename>. See
        <link xlink:href="https://github.com/alacritty/alacritty/blob/master/alacritty.yml"/>
        for the default configuration.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.finalPackage ];
    environment.sessionVariables.TERMINAL = lib.mkDefault "${cfg.finalPackage}/bin/alacritty";
    environment.etc."xdg/alacritty.yml" = mkIf (cfg.settings != {}) {
      # TODO: Replace by the generate function but need to figure out how to
      # handle the escaping first.
      #
      # source = yamlFormat.generate "alacritty.yml" cfg.settings;
      text = replaceStrings [ "\\\\" ] [ "\\" ] (builtins.toJSON cfg.settings);
    };
  };
}
