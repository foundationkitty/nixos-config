{ config, pkgs, lib, ... }:

# Variables

let

    sources = import ./nix/sources.nix;
    lanzaboote = import sources.lanzaboote;

    panasonic-hbtn = config.boot.kernelPackages.callPackage ./pkgs/panasonic-hbtn.nix { };

in
{

  # Imports
 
  imports =
    [
      lanzaboote.nixosModules.lanzaboote
    ];

  # Front Button Drivers

  boot.extraModulePackages = [ panasonic-hbtn ];
  boot.kernelModules = [ "panasonic-hbtn" ];

  # Bootloader
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = config.bootLoaderTimeout;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  # Use Manually Specified Location

  location.provider = "manual";
  location.latitude = config.lat;
  location.longitude = config.long;

  # GPS
  services.gpsd = {
    enable = true;
    devices = [ config.gps-device ];
    extraArgs = config.gps-device-args;
  };

  users.users.gpsd = {
    extraGroups = [ "dialout" ];
  };

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
        flameshot
        foxtrotgps
        gpsd
        gpxsee
        jellyfin
        onboard
        i3status
        lxappearance
        modem-manager-gui
        volumeicon
        xss-lock

     ];
    };
  };

  programs.i3lock.enable = true;

}
