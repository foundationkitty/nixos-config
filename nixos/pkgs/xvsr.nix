{ config, pkgs, lib, ... }:

let
  cfg = config.programs.xvsr;

  xvsr = pkgs.writeShellApplication {
    name = "xvsr";
    runtimeInputs = with pkgs; [ coreutils ffmpeg jq mpv procps wf-recorder ];
    text = ''
      export XVSR_FILTER_PY=${./xvsr-filter.py}
      export XVSR_PYTHON=${pkgs.python312}/bin/python3
      export XVSR_LIBS=${lib.makeLibraryPath (with pkgs; [ stdenv.cc.cc.lib zlib libGL glib ])}
      : "''${XVSR_OUTPUT:=${cfg.output}}"
      : "''${XVSR_IN:=${cfg.streamResolution}}"
      : "''${XVSR_QUALITY:=${cfg.quality}}"
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
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ xvsr ];
  };
}
