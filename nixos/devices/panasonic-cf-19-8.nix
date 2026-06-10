{ config, pkgs, lib, ... }:

# Variables

let

    sources = import ./lon.nix;
    lanzaboote = import sources.lanzaboote { };

    panasonic-hbtn = config.boot.kernelPackages.callPackage ./pkgs/panasonic-hbtn.nix { };

in
{

  services.cloudflare-warp.enable = true;

  # Imports
 
  imports =
    [
      lanzaboote.nixosModules.lanzaboote
    ];

  # Front Button Drivers

  boot.extraModulePackages = [ panasonic-hbtn ];
  boot.kernelModules = [ "panasonic-hbtn" ];

  # WiFi Drivers

  hardware.enableAllFirmware = true;
  hardware.firmware = with pkgs; [ linux-firmware ];

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
    nowait = true;
    readonly = false;
  };

  users.users.gpsd = {
    extraGroups = [ "dialout" ];
  };

  # WM

  services.gnome.gnome-keyring.enable = true;

  programs.sway = {
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

  users.users.${config.user}.packages = with pkgs; [
      brightnessctl
      foxtrotgps
      gpsd
      i3status
      jellyfin
      lxappearance
      modem-manager-gui
      wvkbd
  ];

  programs.i3lock.enable = true;

}
