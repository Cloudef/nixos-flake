{ config, lib, pkgs, inputs, users, ... }:
with lib;
# TODO: eww window for logout shutdown and reboot
# TODO: test eww fork with system tray
# TODO: use https://github.com/Duckonaut/split-monitor-workspaces
let
  cfg = config.programs.hyprland-desktop;

  default-terminal-cmd = [ "${config.programs.alacritty.finalPackage}/bin/alacritty" ];

  terminal-autocd-cmd = let
    wrapped = pkgs.writeShellApplication {
      name = "hyprland-terminal-autocd";
      runtimeInputs = with pkgs; [ procps cfg.finalPackage jaq ];
      text = ''
        if read -r _ cwd < <((pwdx "$(pgrep -P "$(hyprctl activewindow -j | jaq -r .pid)")") 2>/dev/null); then
          cd "$cwd"
        fi
        ${concatStringsSep " " cfg.terminalCmd} "$@"
        '';
    };
  in "${wrapped}/bin/hyprland-terminal-autocd";

  hyprshot = pkgs.stdenv.mkDerivation {
    name = "hyprshot";
    version = "0.0.1";
    buildInputs = [ pkgs.makeWrapper ];
    src = pkgs.fetchFromGitHub {
      owner = "Gustash";
      repo = "Hyprshot";
      rev = "9d9df540409f4587a04324aaefec24a7224f83dc";
      hash = "sha256-f4fMIS3B01F090Cs3R846HwQsmFvdzx8w3ubPi06S5o=";
    };

    dontPatchELF = true;
    dontPatch = true;
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      mkdir -p $out/bin
      install -m755 hyprshot $out/bin/hyprshot
      '';

    postFixup = with pkgs; ''
      wrapProgram $out/bin/hyprshot \
      --set PATH ${lib.makeBinPath [
        coreutils
        gnugrep
        getopt
        jq
        slurp
        grim
        wl-clipboard
        libnotify
        imagemagick
        cfg.finalPackage
      ]}
    '';
  };

  ja-en-translator = pkgs.writeShellApplication {
    name = "ja-en-translator";
    runtimeInputs = with pkgs; [ hyprshot tesseract translate-shell notify-desktop ];
    # TODO: hardcoded DPI
    text = ''
      hyprshot -m region --raw | tesseract --dpi 109 --psm 6 -l jpn - - | \
        trans -show-original-phonetics n --show-translation-phonetics n --show-prompt-message n --show-languages n -no-ansi >/tmp/translation
      notify-desktop  "$(cat /tmp/translation)" >/dev/null
      '';
  };

  monitor-wrangler = pkgs.writeShellApplication {
    name = "monitor-wrangler";
    runtimeInputs = with pkgs; [ cfg.finalPackage jaq ];
    text = ''
      # shellcheck disable=SC2016
      id="$(hyprctl monitors -j | jaq --arg m "$2" 'sort_by(.x)[$m|tonumber].id' 2>/dev/null)"
      if [[ "$id" ]]; then
        case "$1" in
          focusmonitor)
            hyprctl dispatch focusmonitor "$id"
            ;;
          movewindow)
            hyprctl dispatch movewindow mon:"$id"
            ;;
        esac
      fi
      '';
  };

  pipewire-event-handler = pkgs.writeShellApplication {
    name = "pipewire-event-handler";
    runtimeInputs = with pkgs; [ pulseaudio cfg.finalPackage config.programs.eww.finalPackage gnugrep ];
    text = ''
      test "$(eww ping)" = "pong" || exit 1
      cvol="$(${concatStringsSep " " cfg.volumeGetCmd})"
      hyprctl dispatch exec eww update volume="$cvol" >/dev/null
      # shellcheck disable=SC2034
      while read -r _ event _ type num; do
        test "$(eww ping)" = "pong" || exit 1
        # https://github.com/hyprwm/Hyprland/issues/2695
        test -e "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" || exit 1
        case "$event" in
          "'new'")
            if [[ "$type" == "card" ]]; then
              hyprctl notify 1 3000 "rgb(ff1ea3)" "Audio device added" >/dev/null
            fi
            ;;
          "'remove'")
            if [[ "$type" == "card" ]]; then
              hyprctl notify 1 3000 "rgb(ff1ea3)" "Audio device removed" >/dev/null
            fi
            ;;
          "'change'")
            nvol="$(${concatStringsSep " " cfg.volumeGetCmd})"
            if [[ "$nvol" != "$cvol" ]]; then
              hyprctl dispatch exec eww update volume="$nvol" >/dev/null
              cvol="$nvol"
            fi
            ;;
        esac
      done < <(pactl subscribe | grep --line-buffered -Fv " on client ")
    '';
  };

  hyprland-event-handler = pkgs.writeShellApplication {
    name = "hyprland-event-handler";
    runtimeInputs = with pkgs; [ socat cfg.finalPackage config.programs.eww.finalPackage jaq ];
    text = ''
      test "$(eww ping)" = "pong" || exit 1
      hyprctl dispatch exec eww update workspace="$(hyprctl activeworkspace -j | jaq .id)" >/dev/null
      while true; do
        # https://github.com/hyprwm/Hyprland/issues/2695
        test -e "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" || exit 1
        test "$(eww ping)" = "pong" || exit 1
        socat -U -t 3600 - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
          event="''${line/>>*/}"
          args="''${line/*>>/}"
          # shellcheck disable=SC2034
          IFS="," read -r arg1 arg2 arg3 arg4 <<<"$args"
          case "$event" in
            workspace)
              hyprctl dispatch exec eww update workspace="$arg1" >/dev/null
              ;;
            focusedmon)
              hyprctl dispatch exec eww update monitor="$arg1" >/dev/null
              ;;
            activewindow)
              ;;
            activewindowv2)
              hyprctl dispatch exec eww update window="$arg1" >/dev/null
              ;;
            fullscreen)
              ;;
            monitorremoved)
              ;;
            monitoradded)
              ;;
            createworkspace)
              ;;
            destroyworkspace)
              ;;
            moveworkspace)
              ;;
            activelayout)
              ;;
            openwindow)
              ;;
            closewindow)
              ;;
            movewindow)
              ;;
            openlayer)
              ;;
            closelayer)
              ;;
            submap)
              ;;
            changefloatingmode)
              ;;
            urgent)
              ;;
            minimize)
              ;;
            screencast)
              if [[ "$arg1" == 1 ]]; then
                if [[ "$arg2" == 0 ]]; then
                  hyprctl notify 1 3000 "rgb(ff1ea3)" "Screen is being shared" >/dev/null
                elif [[ "$arg2" == 1 ]]; then
                  hyprctl notify 1 3000 "rgb(ff1ea3)" "Window is being shared" >/dev/null
                fi
              fi
              ;;
            windowtitle)
              ;;
          esac
        done
      done
      '';
    };
in {
  imports = [
    ./alacritty.nix
    ./eww.nix
  ];

  options.programs.hyprland-desktop = {
    enable = mkEnableOption (mdDoc "hyprland-desktop");

    fishAutoStart = mkOption {
      type = types.bool;
      default = true;
    };

    debug = mkOption {
      type = types.bool;
      default = false;
    };

    package = mkOption {
      type = types.package;
      default = if (cfg.debug) then pkgs.hyprland-debug else pkgs.hyprland;
      defaultText = literalExpression "pkgs.hyprland";
      description = mdDoc ''
        The package used for the hyprland compositor.
        '';
    };

    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
      default = if (cfg.debug) then pkgs.enableDebugging cfg.package else cfg.package;
      description = "Resulting package.";
    };

    cursorThemePackage = mkOption {
      type = types.package;
      default = pkgs.phinger-cursors;
      defaultText = literalExpression "pkgs.phinger-cursors";
      description = mdDoc ''
        The package used for the cursor theme.
        '';
    };

    terminalCmd = mkOption {
      type = types.listOf types.str;
      default = default-terminal-cmd;
      description = mdDoc ''
        The command used for the terminal emulator.
        '';
    };

    launcherCmd = mkOption {
      type = types.listOf types.str;
      default = [ "${pkgs.bemenu}/bin/bemenu-run" ];
      description = mdDoc ''
        The command used for the launcher.
        '';
    };

    volumeRaiseCmd = mkOption {
      type = types.listOf types.str;
      default = [ "${pkgs.wireplumber}/bin/wpctl" "set-volume" "-l" "1.0" "@DEFAULT_AUDIO_SINK@" "0.025+" ];
      description = mdDoc ''
        The command used for raising the volume.
        '';
    };

    volumeLowerCmd = mkOption {
      type = types.listOf types.str;
      default = [ "${pkgs.wireplumber}/bin/wpctl" "set-volume" "-l" "1.0" "@DEFAULT_AUDIO_SINK@" "0.025-" ];
      description = mdDoc ''
        The command used for lowering the volume.
        '';
    };

    volumeMuteCmd = mkOption {
      type = types.listOf types.str;
      default = [ "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle" ];
      description = mdDoc ''
        The command used for toggling the volume mute.
        '';
    };

    volumeSetCmd = let
      setvol = pkgs.writeScript "setvol" ''
        set -e
        ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ $(echo "scale=2; $1 / 100" | ${pkgs.bc}/bin/bc)
        '';
    in mkOption {
      type = types.listOf types.str;
      default = [ "${setvol}" ];
      description = mdDoc ''
        The command used for setting volume at range 0..100.
        '';
    };

    volumeGetCmd = let
      getvol = pkgs.writeScript "getvol" ''
        set -e
        read -r _ vol muted < <(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@)
        if [[ "$muted" == "[MUTED]" ]]; then
          printf 0
        else
          ${pkgs.bc}/bin/bc <<<"scale=2; $vol * 100"
        fi
        '';
    in mkOption {
      type = types.listOf types.str;
      default = [ "${getvol}" ];
      description = mdDoc ''
        The command used for getting volume at range 0..100.
        '';
    };

    wallpaper = mkOption {
      type = types.path;
      default = ../wallpaper.jpg;
      description = mdDoc ''
        Wallpaper.
        '';
    };

    workspaces = mkOption {
      type = types.listOf types.str;
      default = [ "1" "2" "3" "4" ];
      description = mdDoc ''
        Workspace names.
        '';
    };

    primaryMonitor = mkOption {
      type = types.attrs;
      default = {
        name = "DELL S2722DC";
        adapter = "HDMI-A-1";
        resolution = "highres";
        scale = "1";
      };
      description = mdDoc ''
        Primary monitor config.
        '';
    };

    monitors = mkOption {
      type = types.listOf types.str;
      default = [",highres,auto,1"];
      description = mdDoc ''
        Monitor configuration.
        '';
    };

    extraKeyBindings = mkOption {
      type = types.listOf types.str;
      default = [];
      description = mdDoc ''
        Extra key binding configuration.
        '';
    };

    extraMouseBindings = mkOption {
      type = types.listOf types.str;
      default = [];
      description = mdDoc ''
        Extra mouse binding configuration.
        '';
    };

    extraExecOnce = mkOption {
      type = types.listOf (types.listOf types.str);
      default = [];
      description = mdDoc ''
        Extra exec-once commands.
        '';
    };

    extraExec = mkOption {
      type = types.listOf (types.listOf types.str);
      default = [];
      description = mdDoc ''
        Extra exec commands.
        '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = mdDoc ''
        Extra configuration text appended to {file}`hyprland.conf`. Other generated
        options will be prepended.
        '';
    };
  };

  config = mkIf cfg.enable {
    programs.alacritty = mkIf (cfg.terminalCmd == default-terminal-cmd) { enable = true; };

    nix.settings.substituters = [ "https://hyprland.cachix.org" ];
    nix.settings.trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];

    environment.systemPackages = let
      spacefm = pkgs.writeShellApplication {
        name = "spacefm";
        runtimeInputs = with pkgs; [ spaceFM unzip unrar p7zip ];
        text = ''GDK_BACKEND=x11 exec spacefm "$@"'';
      };
    in with pkgs; [
      cfg.cursorThemePackage
      cfg.finalPackage
      hyprshot
      wl-clipboard
      imv
      wbg
      ja-en-translator
      spacefm
    ];

    # TODO: temps are hardcoded
    programs.eww.enable = true;
    programs.eww.yuck = ''
      (defpoll interface :interval "5m" `ip -j -o route get 8 | jaq -r .[0].dev`)
      (defvar volume "0")
      (defvar workspace "1")
      (defvar monitor "1")
      (defvar window "0")

      (defwidget bar []
        (centerbox :orientation "h"
          (workspaces)
          (box "")
          (sidestuff)))

      (defwidget sidestuff []
        (box :class "sidestuff"
             :orientation "h"
             :space-evenly false
             :halign "end"
             :spacing 18
          "⏶ ''${interface != "" ? round(EWW_NET[interface].NET_UP / 1024, 2) : 0} KB" "⏷ ''${interface != "" ? round(EWW_NET[interface].NET_DOWN / 1024, 2) : 0} KB"
          "GPU ''${round(EWW_TEMPS["AMDGPU_JUNCTION"], 0)}°C"
          "VRM ''${round(EWW_TEMPS["ASUSEC_VRM"], 0)}°C"
          (metric :label "CPU ''${round(EWW_TEMPS["ZENPOWER_TDIE"], 0)}°C"
                  :value {round(EWW_CPU.avg, 0)}
                  :onchange "")
          (metric :label "RAM"
                  :value {EWW_RAM.used_mem_perc}
                  :onchange "")
          (metric :label "DSK"
                  :value {EWW_DISK["/"].used_perc}
                  :onchange "")
          (metric :label "VOL"
                  :value {volume}
                  :onchange "${concatStringsSep " " cfg.volumeSetCmd} {}")
          {formattime(EWW_TIME, "%a %b %d, %Y   %H:%M:%S")}))

      (defwidget workspaces []
        (box :class "workspaces"
             :orientation "h"
             :space-evenly false
             :halign "start"
             :spacing 0
      '' + concatStringsSep "\n" (imap1 (ni: name: let i = toString ni; in ''
          (button :onclick "${cfg.finalPackage}/bin/hyprctl dispatch workspace ${i}"
                  :class {workspace == ${i} ? "active" : "inactive"}
                  ${name})
      '') cfg.workspaces) + ''
        ))

      (defwidget metric [label value onchange]
        (box :orientation "h"
             :class "metric"
             :space-evenly false
          (box :class "label" label)
          (scale :min 0
                 :max 100
                 :active {onchange != ""}
                 :value value
                 :onchange onchange)))

      (defwindow bar
        :monitor "${cfg.primaryMonitor.name}"
        :windowtype "dock"
        :exclusive true
        :focusable false
        :geometry (geometry :x "0%"
                            :y "0%"
                            :width "100%"
                            :height "32px"
                            :anchor "top center")
        :reserve (struts :side "top" :distance "4%")
        (bar))
      '';

    programs.eww.scss = ''
      * { all: unset; }

      .bar {
        background-color: #121212;
        color: #d81860;
      }

      .metric scale trough highlight {
        all: unset;
        background-color: #D35D6E;
        color: #000000;
        border-radius: 4px;
      }

      .metric scale trough {
        all: unset;
        background-color: #4e4e4e;
        border-radius: 4px;
        min-height: 10px;
        min-width: 80px;
        margin-left: 18px;
        margin-bottom: 2px;
      }

      .workspaces button:hover {
        color: white;
      }

      .workspaces .active {
        color: #121212;
        background-color: #d81860;
        min-width: 32px;
      }

      .workspaces .inactive {
        min-width: 32px;
      }

      .workspaces {
        padding-left: 8px;
      }

      .sidestuff {
        padding-right: 24px;
      }
      '';

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    environment.sessionVariables.QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    environment.etc."xdg/hyprland.conf".mode = "0444";
    environment.etc."xdg/hyprland.conf".text = ''
      exec-once = ${cfg.finalPackage}/bin/hyprctl setcursor ${cfg.cursorThemePackage.pname} 24
      exec-once = ${pkgs.wbg}/bin/wbg ${cfg.wallpaper}
      exec-once = sleep 1 && ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP && /run/current-system/systemd/bin/systemctl --user start hyprland-session.target
      exec-once = ${config.programs.eww.finalPackage}/bin/eww open bar
      exec = /run/current-system/systemd/bin/systemctl --user restart pipewire-event-handler.service
      exec = /run/current-system/systemd/bin/systemctl --user restart hyprland-event-handler.service
    '' + concatStringsSep "\n" (
      map (x: "exec-once = ${concatStringsSep " " x}") cfg.extraExecOnce ++
      map (x: "exec = ${concatStringsSep " " x}") cfg.extraExec ++
      [ "monitor = ${cfg.primaryMonitor.adapter},${cfg.primaryMonitor.resolution},0x0,${cfg.primaryMonitor.scale}" ] ++
      map (x: "monitor = ${x}") cfg.monitors
    ) + ''

      input {
        kb_layout = ${config.console.keyMap}
        follow_mouse = 1
        accel_profile = flat
        sensitivity = 0.1
        repeat_rate = 50
        repeat_delay = 250
        scroll_method = on_button_down
      }

      general {
        gaps_in = 0
        gaps_out = -1
        border_size = 0
        col.active_border = rgb(d81860)
        col.inactive_border = rgb(d81860)
      }

      cursor {
        inactive_timeout = 5
      }

      decoration {
        rounding = 0
        blur {
          enabled = true
          size = 3
          passes = 3
          new_optimizations = true
        }
        shadow {
          enabled = true
          ignore_window = true
          offset = 0 5
          range = 50
          render_power = 3
          color = rgba(00000099)
        }
        dim_inactive = true
        dim_strength = 0.20
      }

      animations {
        enabled = true
        animation = border, 1, 2, default
        animation = fade, 1, 4, default
        animation = windows, 1, 3, default, popin 80%
        animation = workspaces, 1, 2, default, slide
      }

      dwindle {
        pseudotile = true
        preserve_split = true
      }

      misc {
        enable_anr_dialog = false
        disable_hyprland_logo = true
        vrr = 1
      }

      # Shadow on floating only
      windowrulev2 = noshadow, floating:0

      # Firefox PiP
      windowrulev2 = float, title:^(Picture-in-Picture)$
      windowrulev2 = pin, title:^(Picture-in-Picture)$
      windowrulev2 = float, title:^(Open Files)$

      # Gamescope
      windowrulev2 = fullscreen,class:(.gamescope-wrapped)
      windowrulev2 = tile,class:(.gamescope-wrapped)

      bind = SUPER, Q, killactive,
      bind = SUPER SHIFT, F, fullscreen,
      bind = SUPER SHIFT, G, togglegroup,
      bind = SUPER SHIFT, N, changegroupactive, f
      bind = SUPER SHIFT, P, changegroupactive, b
      bind = SUPER, R, togglesplit,
      bind = SUPER, T, togglefloating,
      bind = SUPER, left, movefocus, l
      bind = SUPER, right, movefocus, r
      bind = SUPER, up, movefocus, u
      bind = SUPER, down, movefocus, d
      bind = SUPER ALT, left, movewindow, l
      bind = SUPER ALT, right, movewindow, r
      bind = SUPER ALT, up, movewindow, u
      bind = SUPER ALT, down, movewindow, d
      bind = SUPER SHIFT, right, resizeactive, 10 0
      bind = SUPER SHIFT, left, resizeactive, -10 0
      bind = SUPER SHIFT, up, resizeactive, 0 -10
      bind = SUPER SHIFT, down, resizeactive, 0 10

      '' + concatStringsSep "\n" (imap1 (ni: _: let i = toString ni; in ''
        bind = SUPER, F${i}, workspace, ${i}
        bind = SUPER SHIFT, F${i}, movetoworkspacesilent, ${i}
        workspace = ${i},monitor:${cfg.primaryMonitor.adapter}${if i == "1" then ",default:true" else ""}
      '') cfg.workspaces) + ''
      '' + concatMapStringsSep "\n" (x: let i = toString (x - 1); n = toString x; in ''
        bind = SUPER, ${n}, exec, ${monitor-wrangler}/bin/monitor-wrangler focusmonitor ${i}
        bind = SUPER SHIFT, ${n}, exec, ${monitor-wrangler}/bin/monitor-wrangler movewindow ${i}
      '') (range 1 9)
      + ''

      bind = ,XF86AudioRaiseVolume, exec, ${concatStringsSep " " cfg.volumeRaiseCmd}
      bind = ,XF86AudioLowerVolume, exec, ${concatStringsSep " " cfg.volumeLowerCmd}
      bind = ,XF86AudioMute, exec, ${concatStringsSep " " cfg.volumeMuteCmd}
      bind = SUPER, P, exec, ${concatStringsSep " " cfg.launcherCmd}
      bind = SUPER SHIFT, return, exec, ${terminal-autocd-cmd}
      bind = SUPER SHIFT, O, exec, ${hyprshot}/bin/hyprshot -m output -o ~/misc/screenshots
      bind = SUPER SHIFT, W, exec, ${hyprshot}/bin/hyprshot -m window -o ~/misc/screenshots
      bind = SUPER SHIFT, R, exec, ${hyprshot}/bin/hyprshot -m region -o ~/misc/screenshots
      bind = SUPER SHIFT, T, exec, ${ja-en-translator}/bin/ja-en-translator
      '' + concatMapStringsSep "\n" (x: "bind = ${x}") cfg.extraKeyBindings + ''

      bindm = SUPER, mouse:272, movewindow
      bindm = SUPER, mouse:273, resizewindow
      '' + concatMapStringsSep "\n" (x: "bindm = ${x}") cfg.extraMouseBindings + ''

      ${cfg.extraConfig}
      '';

    nixpkgs.overlays = [(final: prev: {
      hyprland = inputs.hyprland.packages.${pkgs.system}.hyprland;
      hyprland-debug = inputs.hyprland.packages.${pkgs.system}.hyprland-debug;
      xdg-desktop-portal-hyprland = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
    })];

    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      package = cfg.finalPackage;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
    };

    home-manager.users = mapAttrs (user: params: { config, pkgs, ... }: {
      programs.fish.interactiveShellInit = mkIf cfg.fishAutoStart ''
        if test -z "$WAYLAND_DISPLAY" -a "9$XDG_VTNR" -eq 91
          /run/current-system/systemd/bin/systemctl --user reset-failed
          /run/current-system/systemd/bin/systemctl --user stop hyprland-session.target
          WAYLAND_DEBUG=${if (cfg.debug) then "1" else "0"} ${cfg.finalPackage}/bin/Hyprland --config /etc/xdg/hyprland.conf &> /tmp/hyprland.log
          /run/current-system/systemd/bin/systemctl --user stop hyprland-session.target
        end
        '';

      systemd.user.services.hyprland-event-handler = {
        Unit.Description = "Hyprland event handler";
        Service.ExecStart = "${hyprland-event-handler}/bin/hyprland-event-handler";
        Service.Restart = "on-failure";
        Install.WantedBy = [ "hyprland-session.target" ];
      };

      systemd.user.services.pipewire-event-handler = {
        Unit.Description = "Pipewire event handler";
        Service.ExecStart = "${pipewire-event-handler}/bin/pipewire-event-handler";
        Service.Restart = "on-failure";
        Install.WantedBy = [ "hyprland-session.target" ];
      };

      systemd.user.services.dunst = let
        config = pkgs.writeText "dunst.conf" ''
          [global]
          offset = 8x10
          follow = mouse
          frame_width = 1
          frame_color = "#d81860"
          gap_size = 4
          icon_theme = "Papirus-Dark, Adwaita"
          font = Monospace 9

          [urgency_low]
          background = "#121212"
          foreground = "#d81860"

          [urgency_normal]
          background = "#121212"
          foreground = "#d81860"

          [urgency_critical]
          background = "#121212"
          foreground = "#d81860"
          '';
      in {
        Unit.Description = "Dunst notification daemon";
        Service.ExecStart = "${pkgs.dunst}/bin/dunst -config ${config}";
        Service.Restart = "on-failure";
        Install.WantedBy = [ "hyprland-session.target" ];
      };

      systemd.user.targets.hyprland-session = {
        Unit.Description = "Hyprland compositor session";
        Unit.Documentation = ["man:systemd.special(7)"];
        Unit.BindsTo = ["graphical-session.target"];
        Unit.Wants = ["graphical-session-pre.target"];
        Unit.After = ["graphical-session-pre.target"];
      };
    }) (filterAttrs (n: v: n != "root") users);
  };
}
