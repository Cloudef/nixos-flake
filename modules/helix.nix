{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.helix;
in {
  disabledModules = ["programs/helix.nix"];

  options.programs.helix = {
    enable = mkEnableOption (mdDoc "Helix");

    package = mkOption {
      type = types.package;
      default = pkgs.evil-helix;
      defaultText = literalExpression "pkgs.helix";
      description = "The Helix package to install.";
    };

    finalPackage = let
      wrapped = pkgs.writeScriptBin "hx" ''
        ${cfg.package}/bin/hx --config /etc/xdg/helix.toml "$@"
        '';
    in mkOption {
      type = types.package;
      readOnly = true;
      default = wrapped;
      description = "The wrapped package that reads configuration from /etc/xdg/helix.toml.";
    };

    settings = mkOption {
      type = types.str;
      default = ''
        theme = "ayu_evolve"
        [editor]
        cursorline = true
        auto-completion = true
        auto-format = true
        bufferline = "always"
        insert-final-newline = false
        trim-final-newlines = true
        trim-trailing-whitespace = true
        indent-guides.render = true
        indent-guides.character = "┆"

        [keys.normal]
        C-e = ":buffer-next"
        C-q = ":buffer-previous"
        '';
      description = ''
        Configuration written to
        <filename>/etc/xdg/helix.toml</filename>.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.finalPackage ];
    environment.sessionVariables.EDITOR = lib.mkDefault "${cfg.finalPackage}/bin/hx";
    environment.etc."xdg/helix.toml" = mkIf (cfg.settings != {}) {
      text = cfg.settings;
    };
  };
}
