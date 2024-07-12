{ config, pkgs, lib, ... }:

# Variables
let

    panasonic-hbtn = config.boot.kernelPackages.callPackage ./panasonic-hbtn.nix { };

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
}

