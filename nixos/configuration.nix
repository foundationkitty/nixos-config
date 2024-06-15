{ config, pkgs, lib, ... }:

# Variables
let

    sources = import ./nix/sources.nix;
    lanzaboote = import sources.lanzaboote;

    unstable = import (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/nixos-unstable)
    {
      config = config.nixpkgs.config;
    };

    panasonic-hbtn = config.boot.kernelPackages.callPackage ./panasonic-hbtn.nix { };

in
{
  # Imports
  imports =
    [
      ./hardware-configuration.nix
      ./variables.nix
      lanzaboote.nixosModules.lanzaboote
    ];

  # Bootloader
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2;

  boot.initrd.luks.devices."luks-${config.luks-uuid}".device = "/dev/disk/by-uuid/${config.luks-uuid}";

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  boot.extraModulePackages = [ panasonic-hbtn ];
  boot.kernelModules = [ "panasonic-hbtn" ];

  # Graphics
  hardware.opengl.driSupport32Bit = true;
  location.provider = "manual";
  location.latitude = config.lat;
  location.longitude = config.long;
  services.redshift = {
    enable = true;
    temperature = {
      day = 5500;
      night = 3700;
    };
  };

  # Fonts
  fonts.packages = with pkgs; [
      corefonts
      vistafonts
  ];

  # Networking
  networking.hostName = config.hostname;
  networking.networkmanager.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  services.gpsd = {
    enable = true;
    devices = [ config.gps-device ];
    extraArgs = config.gps-device-args;
  };

  users.users.gpsd = {
    extraGroups = [ "dialout" ];
  };

  # Sound
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };

  # Printing
  services.printing.enable = true;

  # Locales
  time.timeZone = config.timezone;
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Package Settings
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = config.stateVersion;

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

        alsa-utils
        brightnessctl
        dmenu
        i3status
        lxappearance
        xautolock
        xss-lock

     ];
    };
  };

  services.displayManager.autoLogin.user = config.user;

  # Modules
  programs.dconf.enable = true;
  programs.firefox.enable = true;
  programs.git.enable = true;
  programs.htop.enable = true;
  programs.i3lock.enable = true;
  programs.nm-applet.enable = true;
  programs.steam.enable = true;

  # User
  users.users.${config.user} = {
    isNormalUser = true;
    description = config.fullUser;
    extraGroups = [ "gpsd" "networkmanager" "wheel" ];
    packages = with pkgs; [ # Non-Module Packages

    # Applications
      discord
      flameshot
      foxtrotgps
      kdenlive
      modem-manager-gui
      obs-studio
      unstable.qbittorrent
      ticktick
      vesktop
      volumeicon
      unstable.vscodium

    # Tools
      file
      gpsd
      imagemagick
      jq
      ncdu
      niv
      onboard
      p7zip
      python3
      qemu-utils
      quickemu
      rclone
      sbctl
      tree
      unzip
      virtualenv
      wireguard-tools

    # Games
      unstable.dolphin-emu
      gzdoom
      unstable.melonDS
      openrct2
      prismlauncher
      (unstable.retroarch.override {
        cores = with libretro; [
          easyrpg
          fceumm
          mgba
          mupen64plus
          snes9x
        ];
      })
    ];
  };
}

