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

  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw*", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0306", TAG+="uaccess", MODE="0666"
  '';

  services.resolved.enable = true;

  services.mullvad-vpn.enable = true;

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
  services.printing.drivers = [ pkgs.hplip ];

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
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;
  programs.dconf.enable = true;
  programs.firefox.enable = true;
  programs.git.enable = true;
  programs.htop.enable = true;
  programs.nix-ld.enable = true;
  programs.nm-applet.enable = true;
  programs.thunar.enable = true;

  services.gvfs.enable = true;
  services.tumbler.enable = true;

  programs.steam.enable = true;
  programs.steam.protontricks.enable = true;

  hardware.xpadneo.enable = true;

  xdg.portal = {
    enable = true;
    wlr = {
      enable = true;
      settings.screencast = {
        max_fps = 30;
        chooser_type = "simple";
        chooser_cmd = "cat /home/basil/displays | /run/current-system/sw/bin/wmenu";
      };
    };
    extraPortals = with pkgs;[
      xdg-desktop-portal-gtk
    ];
  };

  # User
  users.users.${config.user} = {
    isNormalUser = true;
    description = config.fullUser;
    extraGroups = [ "gpsd" "networkmanager" "wheel" ];
    packages = with pkgs; [ # Non-Module Packages

    # Applications
      amberol
      calibre
      discord
      flameshot
      gpxsee
      hunspell
      hunspellDicts.en_US
      ledfx
      libreoffice
      jellyfin-rpc
      kdePackages.kdenlive
      kdePackages.okular
      proton-pass
      proton-vpn
      qbittorrent
      signal-desktop
      steam-rom-manager
      ticktick
      vesktop
      vlc
      vscodium

    # Tools
      alsa-utils
      corepack
      dislocker
      file
      gamescope
      git-credential-manager
      icu.dev
      imagemagick
      jq
      lon
      mlt
      ncdu
      openresolv
      pciutils
      p7zip
      python3
      rclone
      sbctl
      sgdboop
      slurp
      sshfs
      tree
      unzip
      usbutils
      virtualenv
      wine
      wireguard-tools
      wlsunset
      xxd

    # Games
      cdecrypt
      cemu
      dolphin-emu
      gzdoom
      melonds
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

