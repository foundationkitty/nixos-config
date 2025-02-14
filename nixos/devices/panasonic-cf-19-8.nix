{ config, pkgs, lib, ... }:

# Variables
let

    panasonic-hbtn = config.boot.kernelPackages.callPackage ./pkgs/panasonic-hbtn.nix { };

in
{

  # Front Button Drivers

  boot.extraModulePackages = [ panasonic-hbtn ];
  boot.kernelModules = [ "panasonic-hbtn" ];

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
