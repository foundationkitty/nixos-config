{ config, pkgs, lib, ... }:

let

    unstable = import (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/nixos-unstable)
    {
      config = config.nixpkgs.config;
    };

in

{

  # Bootloader

  boot.loader.grub = {
    device = config.bootDevice;
    enable = true;
    enableCryptodisk = true;
    useOSProber = true;
  };

  # Graphics

  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
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
    i3status
    filebot
    makemkv
 ];

  # Android

  networking.nftables.enable = false;
  networking.firewall.package = pkgs.iptables-legacy;
  virtualisation.waydroid.enable = true;
  virtualisation.waydroid.package = pkgs.waydroid-nftables;

}
