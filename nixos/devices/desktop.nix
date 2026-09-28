{ config, pkgs, lib, ... }:

let

    sources = import ./lon.nix;
    lanzaboote = import sources.lanzaboote { };

    unstable = import (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/nixos-unstable)
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

  boot.kernelModules = [ "sg" ];

  boot.kernelParams = [ "usbcore.old_scheme_first=1" ];

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
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

  };

  hardware.enableAllFirmware = true;
  hardware.firmware = with pkgs; [ linux-firmware ];

  # Use Manually Specified Location

  location.provider = "manual";
  location.latitude = config.lat;
  location.longitude = config.long;

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
    allowedTCPPorts = [ 5700 ];
    allowedUDPPorts = [ 5700 ];
  };

  # Docker

  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;
  hardware.nvidia-container-toolkit.enable = true;

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
    lxappearance
    makemkv
    wofi
 ];

}
