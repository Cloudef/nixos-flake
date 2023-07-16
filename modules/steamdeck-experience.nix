{ config, lib, pkgs, inputs, ... }:
with lib;
# TODO: Close steam-gamescope when selecting "Switch to desktop"
# XXX: https://github.com/ValveSoftware/steam-for-linux/issues/9705
let
  cfg = config.programs.steamdeck-experience;

  steam-mod = (pkgs.steam.override {
    extraPkgs = pkgs: with pkgs; [
      # steamdeck first boot wizard skip
      (writeScriptBin "steamos-polkit-helpers/steamos-update" ''
        #!${pkgs.stdenv.shell}
        exit 7
      '')
      gamemode
    ];
  });

  steam-gamescope = let
    deckyloader-version = "v2.10.3";
    deckyloader = pkgs.fetchurl {
      url = "https://github.com/SteamDeckHomebrew/decky-loader/releases/download/${deckyloader-version}/PluginLoader";
      executable = true;
      hash = "sha256-tfDMFT3PmQ7ZRIuUcLzaNRweplM1LtvNWgf/y5jbu/Q=";
    };
  in pkgs.writeShellApplication {
    name = "steam-gamescope";
    runtimeInputs = with pkgs; [ coreutils procps inotify-tools gnugrep gnused file gamemode steam-mod steam-mod.run gamescope mangohud ];
    text = ''
      if pgrep '^PluginLoader' >/dev/null; then
        echo "steam-gamescope is already running"
        exit 0
      fi

      tmpdir="$(mktemp -d)"
      trap 'rm -rf "$tmpdir"' EXIT

      patch_plug() {
        if [[ "$(file --dereference --mime "$@")" != *"binary" ]]; then
          # do not use -i because of the inotifywait
          local tmp; tmp="$(mktemp)"
          sed "s,/home/deck/homebrew,$HOME/.steam/deckyloader,g" "$@" > "$tmp"
          sed -i "s,/home/deck/,$HOME/,g" "$tmp"
          if ! cmp --silent "$tmp" "$@"; then
            printf -- "patching '%s'\n" "$@"
            cp -f "$tmp" "$@"
          fi
          rm -f "$tmp"
        fi
      }

      # patch badly written plugins and fix permissions initally
      chmod -R u=rwX,go=rX "$HOME"/.steam/deckyloader
      (grep -rlF '/home/deck/' "$HOME"/.steam/deckyloader/plugins || true) | while read -r path; do patch_plug "$path"; done

      mkfifo "$tmpdir"/inotify.fifo
      inotifywait --monitor -e create -e modify -e attrib -qr "$HOME"/.steam/deckyloader --exclude "$HOME"/.steam/deckyloader/services -o "$tmpdir"/inotify.fifo &
      inotifypid=$!

      # hack to automatically patch plugins and manage perms
      set +e
      while read -r dir event base; do
        file="$dir$base"
        if [[ "$event" == "ATTRIB"* ]]; then
          if [[ -d "$file" ]]; then
            [[ "$(stat -c '%a' "$file")" != "755" ]] && chmod -v 755 "$file"
          else
            [[ "$(stat -c '%a' "$file")" != "644" ]] && chmod -v 644 "$file"
          fi
        elif [[ -f "$file" ]]; then
          patch_plug "$file"
        fi
      done &> "$HOME"/.steam/deckyloader/services/inotifywait.log < "$tmpdir"/inotify.fifo &
      set -e

      # has to be a copy, symlink makes PluginLoader look up files from wrong directory
      rm -f "$HOME"/.steam/deckyloader/services/PluginLoader
      cp -f ${deckyloader} "$HOME"/.steam/deckyloader/services/PluginLoader
      (cd "$HOME"/.steam/deckyloader/services; steam-run ./PluginLoader &> PluginLoader.log) &
      touch "$HOME"/.steam/steam/.cef-enable-remote-debugging
      echo "${deckyloader-version}" > "$HOME"/.steam/deckyloader/services/.loader.version

      export XKB_DEFAULT_LAYOUT="${config.console.keyMap}"
      export SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0

      export STEAM_USE_MANGOAPP=1
      export STEAM_DISABLE_MANGOAPP_ATOM_WORKAROUND=1
      export STEAM_MANGOAPP_HORIZONTAL_SUPPORTED=1
      MANGOHUD_CONFIGFILE=$(mktemp /tmp/mangohud.XXXXXXXX)
      export MANGOHUD_CONFIGFILE
      mkdir -p "$(dirname "$MANGOHUD_CONFIGFILE")"
      echo "no_display" > "$MANGOHUD_CONFIGFILE"

      export STEAM_USE_DYNAMIC_VRS=1
      RADV_FORCE_VRS_CONFIG_FILE=$(mktemp /tmp/radv_vrs.XXXXXXXX)
      export RADV_FORCE_VRS_CONFIG_FILE
      mkdir -p "$(dirname "$RADV_FORCE_VRS_CONFIG_FILE")"
      echo "1x1" > "$RADV_FORCE_VRS_CONFIG_FILE"

      export SRT_URLOPEN_PREFER_STEAM=1
      export STEAM_DISABLE_AUDIO_DEVICE_SWITCHING=1
      export STEAM_MULTIPLE_XWAYLANDS=1
      export STEAM_GAMESCOPE_DYNAMIC_FPSLIMITER=1
      export STEAM_GAMESCOPE_HAS_TEARING_SUPPORT=1
      export STEAM_GAMESCOPE_COLOR_TOYS=1
      export STEAM_GAMESCOPE_TEARING_SUPPORTED=1
      export STEAM_GAMESCOPE_VRR_SUPPORTED=0
      export STEAM_DISPLAY_REFRESH_LIMITS=40,60,75
      export STEAM_ALLOW_DRIVE_UNMOUNT=1
      export STEAM_NIS_SUPPORTED=1
      export QT_IM_MODULE=steam
      export GTK_IM_MODULE=steam
      export XCURSOR_THEME=steam
      export vk_xwayland_wait_ready=false
      export WINEDLLOVERRIDES=dxgi=n

      set +e
      # shellcheck disable=SC2016
      gamemoderun gamescope --fullscreen --xwayland-count 2 \
        -W ${toString cfg.resolution.width} -H ${toString cfg.resolution.height} \
        -w ${toString cfg.internalResolution.width} -h ${toString cfg.internalResolution.height} \
        -o ${toString cfg.unfocusedFramerate} \
        --max-scale ${toString cfg.maxScale} \
        --hide-cursor-delay ${toString cfg.hideCursorDelay} \
        --fade-out-duration ${toString cfg.fadeOutDuration} \
        --steam -- ${pkgs.stdenv.shell} -c \
          'mangoapp& mpid=$!; steam -gamepadui -steamos3 -steampal -steamdeck; kill "$mpid"' \
          &> "$HOME"/.steam/deckyloader/services/gamescope.log
      ret=$?
      set -e

      pgrep '^PluginLoader' | while read -r pid; do kill -SIGKILL "$pid" || true; done
      pkill -P "$BASHPID" mangoapp || true
      pkill -P "$BASHPID" steam || true
      kill "$inotifypid" || true
      exit $ret
      '';
  };

  # NOTE: Japanese locale by default!
  proton = pkgs.writeShellApplication {
    name = "proton";
    runtimeInputs = with pkgs; [ gamemode gamescope steam-mod.run procps ];
    text = ''
      GAMESCOPE_SCALER="''${GAMESCOPE_SCALER:--i}"
      mkdir -p "''${PROTONPREFIX:-$HOME/.local/share/proton}"
      export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"
      export STEAM_COMPAT_DATA_PATH="''${PROTONPREFIX:-$HOME/.local/share/proton}"
      export LANG="''${LC_ALL:-ja_JP.utf8}"
      set +e
      XKB_DEFAULT_LAYOUT="${config.console.keyMap}" \
      SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0 \
      vk_xwayland_wait_ready=false \
      WINEDLLOVERRIDES=dxgi=n \
        gamemoderun gamescope --fullscreen -F fsr \
          -W ${toString cfg.resolution.width} -H ${toString cfg.resolution.height} \
          -w ${toString cfg.internalResolution.width} -h ${toString cfg.internalResolution.height} \
          -o ${toString cfg.unfocusedFramerate} \
          --max-scale ${toString cfg.maxScale} \
          --hide-cursor-delay ${toString cfg.hideCursorDelay} \
          --fade-out-duration ${toString cfg.fadeOutDuration} \
          "$GAMESCOPE_SCALER" -- steam-run "$HOME/.steam/steam/steamapps/common/Proton - Experimental/proton" run "$@"
      ret=$?
      set -e
      pkill -P "$BASHPID" explorer.exe
      exit $ret
      '';
  };
in {
  options.programs.steamdeck-experience = {
    enable = mkEnableOption (mdDoc "steamdeck-experience");

    resolution = mkOption {
      type = types.attrs;
      default = { width = 2560; height = 1440; };
    };

    # use 4K internal res by default, we downscale to 1440p
    internalResolution = mkOption {
      type = types.attrs;
      default = { width = 3840; height = 2160; };
    };

    unfocusedFramerate = mkOption {
      type = types.number;
      default = 60;
    };

    maxScale = mkOption {
      type = types.number;
      default = 2;
    };

    hideCursorDelay = mkOption {
      type = types.number;
      default = 3000;
    };

    fadeOutDuration = mkOption {
      type = types.number;
      default = 200;
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      steam-mod
      steam-gamescope
      proton
    ];
  };
}
