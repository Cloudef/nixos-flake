{ config, lib, pkgs, pid-defer, ... }:
with lib;
# XXX: https://github.com/ValveSoftware/steam-for-linux/issues/9705
let
  cfg = config.programs.steamdeck-experience;

  # fixes steam controller mouse emulation on wayland (note steam is 32bit)
  # TODO: patch so you can pass it WAYLAND_DISPLAY manually, so we can avoid exposing wayland to all apps
  extest = pkgs.pkgsi686Linux.rustPlatform.buildRustPackage rec {
    pname = "extest";
    version = "0.0.1";
    src = pkgs.fetchFromGitHub {
      owner = "Supreeeme";
      repo = pname;
      rev = "1a419a1691c6accaafef6cfc962a06712d4658e9";
      hash = "sha256-q0BqvdIdcUARGmaPOnzPVLtcWFHJeZ9t2jcfYxS0KTk=";
    };

    cargoHash = "sha256-J9HuZwZ3UYyW2unFxBeap80yPCvdVGQ7pfsdI9qU3QE=";
  };

  steam-mod = (pkgs.steam.override {
    extraPkgs = pkgs: with pkgs; [
      # steamdeck first boot wizard skip
      (writeScriptBin "steamos-polkit-helpers/steamos-update" ''
        #!${pkgs.stdenv.shell}
        exit 7
      '')
      # switch to desktop
      (writeScriptBin "steamos-session-select" ''
        #!${pkgs.stdenv.shell}
        kill $PPID
      '')
      gamemode
    ];
    extraLibraries = pkgs: with pkgs; [
      alsa-lib
      pulseaudio
    ];
  });

  gs-env-vars = mangohud: ''
    export HOMETEST_DESKTOP=1
    export HOMETEST_DESKTOP_SESSION=plasma
    export XKB_DEFAULT_LAYOUT="${config.console.keyMap}"
    export SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0
    export STEAM_USE_MANGOAPP=1
    export STEAM_DISABLE_MANGOAPP_ATOM_WORKAROUND=1
    export STEAM_MANGOAPP_PRESETS_SUPPORTED=1
    export STEAM_MANGOAPP_HORIZONTAL_SUPPORTED=1
    export SRT_URLOPEN_PREFER_STEAM=1
    export STEAM_DISABLE_AUDIO_DEVICE_SWITCHING=1
    export STEAM_MULTIPLE_XWAYLANDS=1
    export STEAM_GAMESCOPE_FANCY_SCALING_SUPPORT=1
    export STEAM_GAMESCOPE_DYNAMIC_FPSLIMITER=1
    export STEAM_GAMESCOPE_HAS_TEARING_SUPPORT=1
    export STEAM_GAMESCOPE_COLOR_TOYS=1
    export STEAM_GAMESCOPE_TEARING_SUPPORTED=1
    export STEAM_GAMESCOPE_VRR_SUPPORTED=0
    export STEAM_DISPLAY_REFRESH_LIMITS=30,38,60,75
    export STEAM_ALLOW_DRIVE_UNMOUNT=1
    export STEAM_NIS_SUPPORTED=1
    export STEAM_GAMESCOPE_COLOR_MANAGED=1
    export STEAM_GAMESCOPE_VIRTUAL_WHITE=1
    export STEAM_GAMESCOPE_DYNAMIC_REFRESH_IN_STEAM_SUPPORTED=0
    export QT_IM_MODULE=steam
    export GTK_IM_MODULE=Steam
    export XCURSOR_THEME=steam
    export vk_xwayland_wait_ready=false
    export GAMESCOPE_NV12_COLORSPACE=k_EStreamColorspace_BT601
    export WINEDLLOVERRIDES=dxgi=n
    export WINE_CPU_TOPOLOGY="8:0,1,2,3,4,5,6,7"
    MANGOHUD_CONFIGFILE="$tmpdir"/mangohud.conf
    export MANGOHUD_CONFIGFILE
    cat <<'EOF' > "$MANGOHUD_CONFIGFILE"
    ${mangohud}
    EOF
    export STEAM_USE_DYNAMIC_VRS=1
    RADV_FORCE_VRS_CONFIG_FILE="$tmpdir"/radv_vrs.conf
    export RADV_FORCE_VRS_CONFIG_FILE
    echo "1x1" > "$RADV_FORCE_VRS_CONFIG_FILE"
    export GAMESCOPE_MODE_SAVE_FILE="''${XDG_CONFIG_HOME:-$HOME/.config}/gamescope/modes.cfg"
    mkdir -p "$(dirname "$GAMESCOPE_MODE_SAVE_FILE")"
    touch "$GAMESCOPE_MODE_SAVE_FILE"
    GAMESCOPE_LIMITER_FILE="$tmpdir"/limiter.conf
    export GAMESCOPE_LIMITER_FILE
    touch "$GAMESCOPE_LIMITER_FILE"
  '';

  steam-gamescope = let
    deckyloader-version = "v2.11.1";
    deckyloader = pkgs.fetchurl {
      url = "https://github.com/SteamDeckHomebrew/decky-loader/releases/download/${deckyloader-version}/PluginLoader";
      executable = true;
      hash = "sha256-J1JtF3DqGHDTBVU88uHN5GCgnILDAJ+YOuaTJyLebNQ=";
    };
  in pkgs.writeShellApplication {
    name = "steam-gamescope";

    runtimeInputs = with pkgs; [ pid-defer procps coreutils inotify-tools gnugrep gnused file gamemode steam-mod steam-mod.run gamescope mangohud ];
    text = let
      # TODO: extest needs parent wayland display passed
      payload = pkgs.writeScript "payload" ''
        export GAMESCOPE_WAYLAND_DISPLAY=$WAYLAND_DISPLAY
        defer $$ mangoapp
        unset WAYLAND_DISPLAY NIXOS_OZONE_WL
        export WAYLAND_DISPLAY="$ORIGINAL_WAYLAND_DISPLAY"
        export LD_PRELOAD=${extest}/lib/libextest.so
        steam -gamepadui -steamos3 -steampal -steamdeck &> "$HOME"/.steam/deckyloader/services/steam.log
        '';
      plugin-patcher = pkgs.writeScript "patcher" ''
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

        # patch badly written plugins
        (grep -rlF '/home/deck/' "$HOME"/.steam/deckyloader/plugins || true) | while read -r path; do patch_plug "$path"; done

        mkfifo "$tmpdir"/inotify.fifo
        defer $$ inotifywait --monitor -e create -e modify -e attrib -qr "$HOME"/.steam/deckyloader --exclude "$HOME"/.steam/deckyloader/services -o "$tmpdir"/inotify.fifo

        # has to be a copy, symlink makes PluginLoader look up files from wrong directory
        rm -f "$HOME"/.steam/deckyloader/services/PluginLoader
        cp -f ${deckyloader} "$HOME"/.steam/deckyloader/services/PluginLoader
        (cd "$HOME"/.steam/deckyloader/services; defer $$ steam-run ./PluginLoader &> PluginLoader.log)

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
        done &> "$HOME"/.steam/deckyloader/services/inotifywait.log < "$tmpdir"/inotify.fifo
        '';
    in ''
      if pgrep '^PluginLoader' >/dev/null; then
        echo "steam-gamescope is already running"
        exit 0
      fi

      tmpdir="$(mktemp -d)"
      trap 'rm -rf "$tmpdir"' EXIT

      # deckyloader stuff
      # mkdir -p "$HOME"/.steam/deckyloader/services
      # mkdir -p "$HOME"/.steam/deckyloader/plugins
      # echo "${deckyloader-version}" > "$HOME"/.steam/deckyloader/services/.loader.version
      # touch "$HOME"/.steam/steam/.cef-enable-remote-debugging
      # chmod -R u=rwX,go=rX "$HOME"/.steam/deckyloader
      # defer $$ bash ${plugin-patcher}

      ${gs-env-vars "no_display"}

      export ORIGINAL_WAYLAND_DISPLAY="$WAYLAND_DISPLAY"

      # shellcheck disable=SC2016
      gamemoderun gamescope --fullscreen --expose-wayland --xwayland-count 2 \
        -W ${toString cfg.resolution.width} -H ${toString cfg.resolution.height} \
        -w ${toString cfg.internalResolution.width} -h ${toString cfg.internalResolution.height} \
        -o ${toString cfg.unfocusedFramerate} \
        --max-scale ${toString cfg.maxScale} \
        --hide-cursor-delay ${toString cfg.hideCursorDelay} \
        --fade-out-duration ${toString cfg.fadeOutDuration} \
        --steam -- ${payload} &> "$HOME"/.steam/deckyloader/services/gamescope.log

      # PluginLoader does not play nicely with SIGTERM
      pkill -9 PluginLoader
      # Try cleanup proton incase gamescope window was closed
      pkill -P "$BASHPID" explorer.exe
      '';
  };

  proton = pkgs.writeShellApplication {
    name = "proton";
    runtimeInputs = with pkgs; [ pid-defer steam-mod.run mangohud ];
    text = ''
      if [[ "''${STEAM_USE_MANGOAPP:-0}" == 1 ]]; then
        defer $$ mangoapp
      fi
      mkdir -p "''${PROTONPREFIX:-$HOME/.local/share/proton}"
      export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"
      export STEAM_COMPAT_DATA_PATH="''${PROTONPREFIX:-$HOME/.local/share/proton}"
      steam-run "$HOME/.steam/steam/steamapps/common/Proton - Experimental/proton" waitforexitandrun "$@"
    '';
  };

  # NOTE: Japanese locale by default!
  proton-gs = pkgs.writeShellApplication {
    name = "proton-gs";
    runtimeInputs = with pkgs; [ gamemode gamescope proton ];
    text = ''
      tmpdir="$(mktemp -d)"
      trap 'rm -rf "$tmpdir"' EXIT
      ${gs-env-vars ''
        horizontal
        legacy_layout=0
        table_columns=20
        cpu_stats
        gpu_stats
        ram
        fps
        frametime=0
        frame_timing=1
        hud_no_margin
        gpu_power
        cpu_power
      ''}
      GAMESCOPE_SCALER="''${GAMESCOPE_SCALER:-"-S integer -F nearest"}"
      export LANG="''${LC_ALL:-ja_JP.utf8}"
      # shellcheck disable=SC2086
      gamemoderun gamescope --fullscreen \
        -W ${toString cfg.resolution.width} -H ${toString cfg.resolution.height} \
        -w ${toString cfg.internalResolution.width} -h ${toString cfg.internalResolution.height} \
        -o ${toString cfg.unfocusedFramerate} \
        --max-scale ${toString cfg.maxScale} \
        --hide-cursor-delay ${toString cfg.hideCursorDelay} \
        --fade-out-duration ${toString cfg.fadeOutDuration} \
        $GAMESCOPE_SCALER -- proton "$@"
      '';
  };

  wine = pkgs.writeShellApplication {
    name = "wine";
    runtimeInputs = with pkgs; [ pid-defer wineWowPackages.stagingFull mangohud ];
    text = ''
      if [[ "''${STEAM_USE_MANGOAPP:-0}" == 1 ]]; then
        defer $$ mangoapp
      fi
      defer $$ wineserver -k
      wine "$@"
    '';
  };

  # NOTE: Japanese locale by default!
  wine-gs = pkgs.writeShellApplication {
    name = "wine-gs";
    runtimeInputs = with pkgs; [ gamemode gamescope wine ];
    text = ''
      tmpdir="$(mktemp -d)"
      trap 'rm -rf "$tmpdir"' EXIT
      ${gs-env-vars ''
        horizontal
        legacy_layout=0
        table_columns=20
        cpu_stats
        gpu_stats
        ram
        fps
        frametime=0
        frame_timing=1
        hud_no_margin
        gpu_power
        cpu_power
      ''}
      GAMESCOPE_SCALER="''${GAMESCOPE_SCALER:-"-S integer -F nearest"}"
      export LANG="''${LC_ALL:-ja_JP.utf8}"
      # shellcheck disable=SC2086
      gamemoderun gamescope --fullscreen \
        -W ${toString cfg.resolution.width} -H ${toString cfg.resolution.height} \
        -w ${toString cfg.internalResolution.width} -h ${toString cfg.internalResolution.height} \
        -o ${toString cfg.unfocusedFramerate} \
        --max-scale ${toString cfg.maxScale} \
        --hide-cursor-delay ${toString cfg.hideCursorDelay} \
        --fade-out-duration ${toString cfg.fadeOutDuration} \
        $GAMESCOPE_SCALER -- wine "$@"
      '';
  };
in {
  options.programs.steamdeck-experience = {
    enable = mkEnableOption (mdDoc "steamdeck-experience");

    resolution = mkOption {
      type = types.attrs;
      default = { width = 2560; height = 1440; };
    };

    internalResolution = mkOption {
      type = types.attrs;
      default = { width = 2560; height = 1440; };
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
      steam-mod.run
      steam-gamescope
      proton
      proton-gs
      wine
      wine-gs
    ];
  };
}
