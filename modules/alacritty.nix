{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.alacritty;
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
        ${cfg.package}/bin/alacritty --config-file /etc/xdg/alacritty.toml "$@"
        '';
    in mkOption {
      type = types.package;
      readOnly = true;
      default = wrapped;
      description = "The wrapped package that reads configuration from /etc/xdg/alacritty.toml.";
    };

    settings = mkOption {
      type = types.str;
      default = ''
        [general]
        live_config_reload = true

        [colors.bright]
        black = "#4d4d4d"
        blue = "#aaccbb"
        cyan = "#a3babf"
        green = "#bde077"
        magenta = "#bb4466"
        red = "#f00060"
        white = "#6c887a"
        yellow = "#ffe863"

        [colors.normal]
        black = "#1c1c1c"
        blue = "#66aabb"
        cyan = "#5e7175"
        green = "#b7ce42"
        magenta = "#b7416e"
        red = "#d81860"
        white = "#ddeedd"
        yellow = "#fea63c"

        [colors.primary]
        background = "#121212"
        foreground = "#cacaca"

        [font]
        size = 11

        [font.bold]
        family = "Hack Nerd Font Mono"
        style = "Bold"

        [font.bold_italic]
        family = "Hack Nerd Font Mono"
        style = "Bold Italic"

        [font.italic]
        family = "Hack Nerd Font Mono"
        style = "Italic"

        [font.normal]
        family = "Hack Nerd Font Mono"
        style = "Regular"

        [scrolling]
        history = 65536

        [window]
        decorations = "none"
        dynamic_padding = true

        [window.padding]
        x = 4
        y = 2
        '';
      description = ''
        Configuration written to
        <filename>/etc/xdg/alacritty.toml</filename>. See
        <link xlink:href="https://github.com/alacritty/alacritty/blob/master/alacritty.toml"/>
        for the default configuration.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.finalPackage ];
    environment.sessionVariables.TERMINAL = lib.mkDefault "${cfg.finalPackage}/bin/alacritty";
    environment.etc."xdg/alacritty.toml" = mkIf (cfg.settings != {}) {
      text = cfg.settings;
    };
  };
}
