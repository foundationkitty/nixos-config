{ config, pkgs, lib, ... }:

# Variables
let

    sources = import ./nix/sources.nix;
    lanzaboote = import sources.lanzaboote;

    unstable = import (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/nixos-unstable)
    {
      config = config.nixpkgs.config;
    };

#    myfork = import (builtins.fetchTarball https://github.com/foundationkitty/nixpkgs/tarball/master)
#    {
#      config = config.nixpkgs.config;
#    };

in
{
  # Imports
  imports =
    [
      ./device-conf.nix
      ./hardware-configuration.nix
      ./variables.nix
      lanzaboote.nixosModules.lanzaboote
    ];

  # Bootloader
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  swapDevices = [ {
    device = "/var/lib/swapfile";
    size = config.swapSize;
   } ];

  # Graphics
  hardware.graphics.enable32Bit = true;

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
  programs.nix-ld.enable = true;
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
      gpxsee
      hunspell
      hunspellDicts.en_US
      jellyfin
      libreoffice
      kdenlive
      modem-manager-gui
      qbittorrent
      ticktick
      vesktop
      volumeicon
      unstable.vscodium

    # Tools
      appimage-run
      corepack
      file
      gpsd
      imagemagick
      jq
      mlt
      ncdu
      niv
      onboard
      openresolv
      p7zip
      python3
      rclone
      sbctl
      tree
      unzip
      virtualenv
      wireguard-tools
      xxd

    # Games
      dolphin-emu
      gzdoom
      unstable.melonDS
      openrct2
      prismlauncher
      (retroarch.override {
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

