{ config, pkgs, lib, ... }:

# Variables
let

    unstable = import (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/nixos-unstable)
    {
      config = config.nixpkgs.config;
    };

    myfork = import (builtins.fetchTarball https://github.com/foundationkitty/nixpkgs/tarball/myfork)
    {
      config = config.nixpkgs.config;
    };

    pinball = import (builtins.fetchTarball https://github.com/nmoya/nixpkgs/tarball/vpinball)
    {
      config = config.nixpkgs.config;
    };

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

  hardware.uinput.enable = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw*", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0306", TAG+="uaccess", MODE="0666"
    KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
    KERNEL=="hidraw*", ATTRS{idVendor}=="1ccf", ATTRS{idProduct}=="1014", MODE="0660", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="1ccf", ATTRS{idProduct}=="1014", MODE="0660", TAG+="uaccess"
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
    jack.enable = true;
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
  services.usbmuxd.enable = true;

  programs.steam.enable = true;
  programs.steam.protontricks.enable = true;

  hardware.xpadneo.enable = true;

  xdg.portal = {
    enable = true;
    config.common.default = "gtk";
    wlr = {
      enable = true;
      settings.screencast = {
        max_fps = 30;
        chooser_type = "dmenu";
        chooser_cmd = "${pkgs.bemenu}/bin/bemenu";
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
    extraGroups = [ "gpsd" "input" "networkmanager" "wheel" ];
    packages = with pkgs; [ # Non-Module Packages

    # Applications
      amberol
      calibre
      dconf-editor
      discord
      unstable.flameshot
      gpxsee
      hunspell
      hunspellDicts.en_US
      ledfx
      libreoffice
      unstable.iloader
      jellyfin-rpc
      kdePackages.kdenlive
      kdePackages.okular
      proton-pass
      proton-vpn
      qbittorrent
      signal-desktop
      steam-rom-manager
      myfork.ticktick
      vesktop
      vlc
      vscodium

    # Tools
      alsa-utils
      bemenu
      corepack
      dislocker
      dxvk
      evsieve
      file
      ffmpeg-full
      gamescope
      git-credential-manager
      grim
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-libav
      icu.dev
      imagemagick
      jq
      libimobiledevice
      libstrangle
      lon
      mlt
      msitools
      ncdu
      openresolv
      pciutils
      p7zip
      (python3.withPackages (ps: [ ps.evdev]))
      rclone
      sbctl
      unstable.sgdboop
      socat
      slurp
      sshfs
      tree
      unzip
      usbutils
      virtualenv
      wget
      wineWow64Packages.stagingFull
      winetricks
      wireguard-tools
      wl-clipboard
      wlsunset
      xxd
      zenity

    # Games
      cdecrypt
      cemu
      dolphin-emu
      dusklight
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
      unnamed-sdvx-clone
      pinball.vpinball
      unstable.vpxtool
    ];
  };
}

