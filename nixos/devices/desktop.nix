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

  # Use Manually Specified Location

  location.provider = "manual";
  location.latitude = config.lat;
  location.longitude = config.long;

  # Desktop Config

    services.xserver = {
    enable = true;
    xkb.layout = "us";
    xkb.variant = "";

    desktopManager = {
      xterm.enable = false;
    };

    displayManager.lightdm.enable = true;

    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [

        brightnessctl
        dmenu
        i3status
        lxappearance
        volumeicon
        xss-lock

     ];
    };
  };

  # Appimage Libs

  programs.appimage.package = pkgs.appimage-run.override { extraPkgs = pkgs: [
    pkgs.zstd
    pkgs.libxcb-cursor
    pkgs.icu
  ]; };

  services.flatpak.enable = true;

  users.users.${config.user}.packages = with pkgs; [
    filebot
    makemkv
    weston
    unstable.zelda64recomp
  ];

  # Android

  virtualisation.waydroid.enable = true;

  programs.i3lock.enable = true;

}
