{ config, pkgs, lib, ... }:

# Variables

let

    unstable = import (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/nixos-unstable)
    {
      config = config.nixpkgs.config;
    };

    sources = import ./lon.nix;
    lanzaboote = import sources.lanzaboote { };
    
in
{

  # Imports
 
  imports =
    [
      lanzaboote.nixosModules.lanzaboote
    ];

  # Laptop can't correctly suspend if wlan is active
  powerManagement = {
    powerDownCommands = ''
      ${pkgs.util-linux}/bin/rfkill block wlan
    '';
    resumeCommands = ''
      ${pkgs.util-linux}/bin/rfkill unblock wlan
    '';
  };

  # Bootloader
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = config.bootLoaderTimeout;

  # Interferes with Fn- action keys
  boot.kernelParams = [ "video.report_key_events=0" ];
  
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  # Graphics

  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    prime = {

        sync.enable = true;
        
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";

    };

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

  users.users.${config.user}.packages = with pkgs; [
    weston
    unstable.zelda64recomp
  ];

  # Android

  virtualisation.waydroid.enable = true;

  programs.i3lock.enable = true;

}
