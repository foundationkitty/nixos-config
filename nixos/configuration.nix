{ config, pkgs, lib, ... }:

# Variables
let

    sources = import ./nix/sources.nix;
    lanzaboote = import sources.lanzaboote;
    unstable = import (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/nixos-unstable)
    {
      config = config.nixpkgs.config;
    };

    fullUser = config.fullUser;
    hostname = config.hostname;
    luks-uuid = config.luks-uuid;
    user = config.user;

in
{
  # Imports
  imports =
    [
      ./variables.nix
      ./hardware-configuration.nix
      lanzaboote.nixosModules.lanzaboote
    ];

  # Bootloader
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2;

  # Secureboot
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  # Encryption
  boot.initrd.luks.devices."luks-${config.luks-uuid}".device = "/dev/disk/by-uuid/${config.luks-uuid}";

  # Networking
  networking.hostName = config.hostname;
  networking.networkmanager.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Locales
  time.timeZone = "America/Los_Angeles";
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

  # WM and DM config
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
        dex
        dmenu
        i3status
     ];
    };
  };

  # Printing
  services.printing.enable = true;

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

  # User account and packages
  users.users.${user} = {
    isNormalUser = true;
    description = config.fullUser;
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ # Non-Module Packages
      alsa-utils
      brightnessctl
      discord
      flameshot
      gzdoom
      imagemagick
      ncdu
      niv
      openrct2
      sbctl
      tree
      unstable.ticktick
      unzip
      vscodium
    ];
  };

  # Programs
  programs.firefox.enable = true;
  programs.git.enable = true;
  programs.htop.enable = true;
  programs.i3lock.enable = true;
  programs.nm-applet.enable = true;
  programs.steam.enable = true;
  programs.xss-lock.enable = true;

  # 32-Bit OpenGL Support
  hardware.opengl.driSupport32Bit = true; 

  # RedShift Configuration
  location.provider = "geoclue2";
  services.redshift = {
    enable = true;
    temperature = {
      day = 5500;
      night = 3700;
    };
  };

  # Unfree Packages
  nixpkgs.config.allowUnfree = true;

  # System Version
  system.stateVersion = "23.11";
}

