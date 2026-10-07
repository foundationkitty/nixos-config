{ config, pkgs, lib, ... }:

let

    sources = import ./lon.nix;
    lanzaboote = import sources.lanzaboote { };

    unstable = import (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/nixos-unstable)
    {
      config = config.nixpkgs.config;
    };

    mmv200 = import (builtins.fetchTarball https://github.com/yzhou216/nixpkgs/tarball/makemkv-bump)
    {
      config = config.nixpkgs.config;
    };

in

{

  imports = [
    ./pkgs/waydroid-nv.nix
    lanzaboote.nixosModules.lanzaboote
  ];

  # Bootloader

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = config.bootLoaderTimeout;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  boot.kernelModules = [ "sg" "v4l2loopback" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=10 card_label="Vive Cam" exclusive_caps=1
  '';

  boot.lanzaboote.configurationLimit = 5;

  boot.kernelParams = [ "usbcore.old_scheme_first=1" ];

  boot.consoleLogLevel = 3;

  hardware.rasdaemon.enable = true;

  # Secondary storage

  boot.supportedFilesystems = [ "ntfs" ];
  systemd.tmpfiles.rules = [
    "d /etc/bitlocker 0700 root root -"
  ];

  environment.etc.crypttab.text = ''
    storage      UUID=${config.storageuuid}    /etc/bitlocker/storage.key  bitlk,nofail
    crucial      UUID=${config.crucialuuid}    /root/secret.key  luks,nofail
  '';

  fileSystems."/mnt/storage" = {
    device = "/dev/mapper/storage";
    fsType = "ntfs3";
    options = [
      "rw"
      "uid=1000"
      "gid=100"
      "umask=007"
      "nofail"
      "force"
    ];
  };

  fileSystems."/mnt/crucial" = {
    device = "/dev/mapper/crucial";
    fsType = "ext4";
    options = [
      "nofail"
    ];
  };

  # Graphics

  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaPersistenced = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

  };

  systemd.services.gpu-undervolt = {
    description = "Apply GPU undervolt";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3.withPackages (ps: [ ps.nvidia-ml-py ])}/bin/python3 /home/${config.user}/.config/scripts/uv.py 1815 150";
      Environment = "LD_LIBRARY_PATH=/run/opengl-driver/lib";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  hardware.enableAllFirmware = true;
  hardware.firmware = with pkgs; [ linux-firmware ];

  # Use Manually Specified Location

  location.provider = "manual";
  location.latitude = config.lat;
  location.longitude = config.long;

  # Local LLM

  services.ollama = { enable = true; package = pkgs.ollama-cuda; };
  services.ollama.host = "${config.localip}";

  systemd.services.qwen-rvn = {
    description = "qwen server";
    serviceConfig = {
      User = config.user;
      ExecStart = "/etc/profiles/per-user/${config.user}/bin/llama-server"
        + " -m /home/${config.user}/models/RVN-Q4_K_M-multilingual.gguf"
        + " --mmproj /home/${config.user}/models/mmproj-Qwen3.8-27B-Q8_0.gguf"
        + " --no-mmproj-offload -np 1"
        + " -c 16384 -ngl 30 --host 0.0.0.0 --port 8080 --jinja";
      Restart = "on-failure";
    };
  };

  # WM

  services.gnome.gnome-keyring.enable = true;

  programs.sway = {
    package = unstable.sway;
    enable = true;
    wrapperFeatures.gtk = true;
  };

  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = {
        command = "sway --unsupported-gpu";
        user = "${config.user}";
      };
      default_session = initial_session;
    };
  };

  # Ports

  networking.firewall = {
    allowedTCPPorts = [ 5700 11434 8000 8080 ];
    allowedUDPPorts = [ 5700 ];
  };

  # Docker

  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;
  hardware.nvidia-container-toolkit.enable = true;

  # Vive Cam

  systemd.user.services.vive-cam = {
    description = "Vive camera";
    serviceConfig = {
      ExecStart = "${pkgs.ffmpeg}/bin/ffmpeg -hide_banner -loglevel error -f v4l2 -input_format yuyv422 -i /dev/v4l/by-id/usb-Alpha_Imaging_Tech_HTC_Vive-video-index0 -vf scale=640:480 -pix_fmt yuv420p -f v4l2 /dev/video10";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Appimage Libs

  programs.appimage.package = pkgs.appimage-run.override { extraPkgs = pkgs: [
    pkgs.zstd
    pkgs.libxcb-cursor
    pkgs.icu
  ]; };

  services.flatpak.enable = true;
  services.jackett.enable = true;
  services.jackett.package = unstable.jackett;

  services.openssh.enable = true;

  users.users.${config.user}.packages = with pkgs; [
    brightnessctl
    i3status
    (filebot.overrideAttrs (old: {
      src = pkgs.fetchurl {
        url = "https://get.filebot.net/filebot/FileBot_${old.version}/FileBot_${old.version}-portable.tar.xz";
        hash = "sha256-OcXXKaZcBuP584SJWeQB+aaxO0kih6Oiud0Vm8e9kPo=";
      };
    }))
    (llama-cpp.override { cudaSupport = true; })
    lxappearance
    mmv200.makemkv
    v4l-utils
    wofi
 ];

}
