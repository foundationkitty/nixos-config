{ config, pkgs, lib, ... }:

let
  cfg = config.programs.xvsr;

  xvsr = pkgs.writeShellApplication {
    name = "xvsr";
    runtimeInputs = with pkgs; [ coreutils ffmpeg jq mpv procps wf-recorder ];
    excludeShellChecks = [ "SC2016" ];
    text = ''
      export XVSR_FILTER_PY=${./xvsr-filter.py}
      export XVSR_PYTHON=${pkgs.python312}/bin/python3
      export XVSR_LIBS=${lib.makeLibraryPath (with pkgs; [ stdenv.cc.cc.lib zlib libGL glib ])}
      : "''${XVSR_OUTPUT:=${cfg.output}}"
      : "''${XVSR_IN:=${cfg.streamResolution}}"
      : "''${XVSR_QUALITY:=${cfg.quality}}"
      export XVSR_RPC_PY=${./xvsr-rpc.py}
      export XVSR_RPC=${if cfg.discord.enable then "1" else "0"}
      export XVSR_GAME=''${XVSR_GAME-${lib.escapeShellArg cfg.discord.game}}
      export XVSR_DISCORD_ID=''${XVSR_DISCORD_ID-${lib.escapeShellArg (toString cfg.discord.clientId)}}
      export XVSR_RPC_DETAILS=${lib.escapeShellArg (toString cfg.discord.details)}
      export XVSR_RPC_STATE=${lib.escapeShellArg (toString cfg.discord.state)}
    '' + builtins.readFile ./xvsr.sh;
  };
in
{
  options.programs.xvsr = {
    enable = lib.mkEnableOption "xvsr";

    output = lib.mkOption {
      type = lib.types.str;
      default = "DP-2";
    };

    streamResolution = lib.mkOption {
      type = lib.types.str;
      default = "1920x1080";
    };

    quality = lib.mkOption {
      type = lib.types.str;
      default = "STREAMING_ULTRA";
    };

    discord = {
      enable = lib.mkEnableOption "discord status while xvsr runs";

      game = lib.mkOption {
        type = lib.types.str;
        default = "Grand Theft Auto VI";
      };

      clientId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      details = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      state = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ xvsr ];
  };
}
