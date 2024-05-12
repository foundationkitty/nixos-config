{ config, pkgs, lib, ... }:

# Variables
let

    sources = import ./nix/sources.nix;
    lanzaboote = import sources.lanzaboote;

    master = import (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/master)
    {
      config = config.nixpkgs.config;
    };

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

  # Networking
  networking.hostName = config.hostname;
  networking.networkmanager.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

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
  system.stateVersion = "23.11";

  # Modules
  programs.dconf.enable = true;
  programs.firefox.enable = true;
  programs.git.enable = true;
  programs.htop.enable = true;
  programs.i3lock.enable = true;
  programs.nm-applet.enable = true;
  programs.steam.enable = true;

  # Desktop Config
  services.xserver = {
    enable = true;
    layout = "us";
    xkbVariant = "";
    xautolock.enable = true;

    desktopManager = {
      xterm.enable = false;
    };
   
    displayManager = {
      lightdm.enable = true;
      autoLogin.user = config.user;
    };

    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [

        alsa-utils
        brightnessctl
        dex
        dmenu
        i3status
        lxappearance
        xss-lock

     ];
    };
  };

  # User
  users.users.${config.user} = {
    isNormalUser = true;
    description = config.fullUser;
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ # Non-Module Packages

    # Applications
      discord
      flameshot
      kodi
      modem-manager-gui
      qbittorrent
      master.qgis
      master.ticktick
      vscodium

    # Games
      gzdoom
      master.openrct2
      master.prismlauncher

    # Tools
      imagemagick
      jq
      ncdu
      niv
      p7zip
      python3
      rclone
      sbctl
      tree
      unzip
      virtualenv
      wireguard-tools

    ];
  };
}

