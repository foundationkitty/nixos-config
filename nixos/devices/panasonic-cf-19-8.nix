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

  # GPS
  services.gpsd = {
    enable = true;
    devices = [ "/run/gps-mm" ];
    nowait = true;
    readonly = true;
    extraArgs = [ ];
  };

  systemd.services.mc7355-gps = {
    description = "Enable MC7355 GNSS via ModemManager";
    after = [ "ModemManager.service" ];
    wants = [ "ModemManager.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.modemmanager pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = 5;
      ExecStart = pkgs.writeShellScript "mc7355-gps-start" ''
        set -eu
        for i in $(seq 1 30); do
          mmcli -m any >/dev/null 2>&1 && break
          sleep 2
        done
        mmcli -m any --location-enable-gps-nmea
        mmcli -m any --location-enable-gps-raw || true
      '';
    };
  };

  systemd.services.mm-nmea-tcp = {
    description = "Serve ModemManager NMEA to gpsd via PTY";
    after = [ "mc7355-gps.service" ];
    requires = [ "mc7355-gps.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.modemmanager pkgs.socat pkgs.coreutils ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 2;
      ExecStopPost = "${pkgs.coreutils}/bin/rm -f /run/gps-mm";
      ExecStart = let
        feeder = pkgs.writeScript "mm-nmea-feeder" ''
          #!${pkgs.python3}/bin/python3
          import re, subprocess, sys, time
          pat = re.compile(r"\$[A-Z]{2}[A-Z0-9]*,[^\s]*")
          while True:
              r = subprocess.run(
                  ["mmcli", "-m", "any", "--location-get"],
                  capture_output=True, text=True,
              )
              for s in pat.findall(r.stdout):
                  print(s, flush=True)
              time.sleep(1)
        '';
      in "${pkgs.bash}/bin/bash -c '${feeder} | ${pkgs.socat}/bin/socat -u STDIN PTY,link=/run/gps-mm,rawer,echo=0,mode=0666'";
    };
  };

  systemd.services.gpsd = {
    after = [ "mm-nmea-tcp.service" ];
    wants = [ "mm-nmea-tcp.service" ];
    serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/timeout 10 ${pkgs.bash}/bin/bash -c 'until test -e /run/gps-mm; do sleep 0.2; done'";
  };

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

  # Android

  virtualisation.waydroid.enable = true;
  virtualisation.waydroid.package = pkgs.waydroid-nftables;

}
