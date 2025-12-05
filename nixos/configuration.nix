{ config, pkgs, lib, ... }:

# Variables
let

    unstable = import (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/nixos-unstable)
    {
      config = config.nixpkgs.config;
    };

    #myfork = import (builtins.fetchTarball https://github.com/foundationkitty/nixpkgs/tarball/myfork)
    #{
    #  config = config.nixpkgs.config;
    #};

in
{
  # Imports
  imports =
    [
      ./device-conf.nix
      ./hardware-configuration.nix
      ./variables.nix
    ];

  # Swap

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
      vista-fonts
  ];

  # Networking
  networking.hostName = config.hostname;
  networking.networkmanager.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  services.resolved.enable = true;

  services.mullvad-vpn.enable = true;
  services.mullvad-vpn.package = unstable.mullvad-vpn;

  # Sound
  services.pulseaudio.enable = false;
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
  i18n.defaultLocale = config.locale;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = config.locale;
    LC_IDENTIFICATION = config.locale;
    LC_MEASUREMENT = config.locale;
    LC_MONETARY = config.locale;
    LC_NAME = config.locale;
    LC_NUMERIC = config.locale;
    LC_PAPER = config.locale;
    LC_TELEPHONE = config.locale;
    LC_TIME = config.locale;
  };

  # Package Settings
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = config.stateVersion;

  services.displayManager.autoLogin.user = config.user;

  # Modules
  programs.dconf.enable = true;
  programs.firefox.enable = true;
  programs.git.enable = true;
  programs.htop.enable = true;
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
      calibre
      discord
      hunspell
      hunspellDicts.en_US
      libreoffice
      kdePackages.kdenlive
      protonvpn-gui
      qbittorrent
      ticktick
      vesktop
      vscodium

    # Tools
      alsa-utils
      appimage-run
      corepack
      file
      git-credential-manager
      imagemagick
      jq
      mlt
      ncdu
      niv
      openresolv
      p7zip
      python3
      rclone
      sbctl
      signal-desktop
      tree
      unzip
      virtualenv
      wireguard-tools
      xxd

    # Games
      unstable.dolphin-emu
      gzdoom
      melonDS
      openrct2
      prismlauncher
      (retroarch.withCores (cores: with cores; [
        easyrpg
        fceumm
        mgba
        mupen64plus
        snes9x
      ]))
    ];
  };
}

