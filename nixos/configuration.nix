{ config, pkgs, lib, ... }:

# Variables
let

    unstable = import (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/nixos-unstable)
    {
      config = config.nixpkgs.config;
    };

    master = import (builtins.fetchTarball https://github.com/foundationkitty/nixpkgs/tarball/master)
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

    wine = master.wineWow64Packages.stagingFull;

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
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      ipafont
      kochi-substitute
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
    KERNEL=="hidraw*", ATTRS{idVendor}=="1ccf", ATTRS{idProduct}=="1014", MODE="0666", GROUP="input"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="1ccf", ATTRS{idProduct}=="1014", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="f822", ATTRS{idProduct}=="0148", GROUP="users", MODE="0660"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="f822", ATTRS{idProduct}=="0148", ENV{ID_MM_DEVICE_IGNORE}="1"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0e8f", MODE="0660", GROUP="users"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0e8f", MODE="0660", GROUP="users"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0ca3", ATTRS{idProduct}=="0021", MODE="0660", GROUP="users"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0ca3", ATTRS{idProduct}=="0021", MODE="0660", GROUP="users"
    KERNEL=="ttyACM*", ATTRS{idVendor}=="0ca3", ATTRS{idProduct}=="0021", MODE="0660", GROUP="users", ENV{ID_MM_DEVICE_IGNORE}="1"
    SUBSYSTEM=="sound", ACTION=="add", KERNEL=="controlC*", ATTRS{idVendor}=="3142", ATTRS{idProduct}=="a010", RUN+="${pkgs.alsa-utils}/bin/amixer -c %n sset Mic playback 0%% mute"
 '';

  hardware.flipperzero.enable = true;

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
  programs.gamescope.enable = true;
  programs.gamescope.capSysNice = true;
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
  programs.steam.extraPackages = [ pkgs.gamescope pkgs.perl ];
  programs.steam.package = pkgs.steam.override {
    extraLibraries = p: with p; [
      alsa-lib dbus fontconfig freetype gmp gnutls libgcrypt
      libpulseaudio libusb1 opus pcsclite pipewire SDL2
      stdenv.cc.cc.lib wayland
      libx11 libxcomposite libxcursor libxext libxfixes libxi
      libxinerama libxrandr libxrender libxxf86vm
    ];
  };

  hardware.xpadneo.enable = true;

  xdg.portal = {
    enable = true;
    config.common.default = "gtk";
    wlr = {
      enable = true;
      settings.screencast = {
        max_fps = 30;
        chooser_type = "dmenu";
        chooser_cmd = "/home/${config.user}/.config/scripts/screen-pick";
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
      master.iloader
      kdePackages.kdenlive
      kdePackages.okular
      proton-pass
      proton-vpn
      qbittorrent
      signal-desktop
      unstable.steam-rom-manager
      myfork.ticktick
      unstable.vesktop
      vlc
      vscodium

    # Tools
      alsa-utils
      android-tools
      autoconf
      automake
      bemenu
      binutils
      bison
      cargo-xwin
      corepack
      dislocker
      e2fsprogs
      evsieve
      file
      ffmpeg-full
      flex
      gcc
      git-credential-manager
      glib
      gnumake
      grim
      gsettings-desktop-schemas
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
      libu2f-host
      libusb1
      llvmPackages.clang-unwrapped
      llvmPackages.lld
      llvmPackages.llvm
      lon
      mlt
      ncdu
      openresolv
      pciutils
      p7zip
      pam_u2f
      patch
      pkg-config
      poppler-utils
      (python3.withPackages (ps: [ ps.evdev ps.dbus-python ps.flask ps.pygobject3 ps.pyusb ps.pypresence ps.pyserial  ps.huggingface-hub ]))
      rclone
      rustup
      sbctl
      screen
      unstable.sgdboop
      socat
      slurp
      sshfs
      tree
      unrar
      unzip
      usbutils
      virtualenv
      wget
      wine
      (unstable.winetricks.overrideAttrs (old: {
        postInstall = old.postInstall + ''
          wrapProgram $out/bin/winetricks --set-default WINE_BIN ${wine}/bin/.wine
        '';
      }))
      wireguard-tools
      wl-clipboard
      wlsunset
      xxd
      yubikey-manager
      yubikey-personalization
      zenity

    # Games
      cdecrypt
      cemu
      dolphin-emu
      unstable.dusklight
      gzdoom
      (melonds.overrideAttrs (old: {
        pname = "melonDS-x432r-plus";
        version = "0.2.2";
        src = pkgs.fetchFromGitHub {
          owner = "ZironZ";
          repo = "melonDS-X432R-Plus";
          rev = "v0.2.2";
          hash = "sha256-7/tJuaN7+qa838fFP/vMPI7jkSsW6xsB0Hb+EXnghSY=";
        };
      }))
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

