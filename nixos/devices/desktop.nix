{ config, pkgs, lib, ... }:

{

  imports =
    [
      ./devices/desktop-virt.nix
    ];

  # Bootloader

  boot.loader.grub = {
    device = config.bootDevice;
    enable = true;
    enableCryptodisk = true;
  };

  specialisation."VFIO".configuration = {
    system.nixos.tags = [ "with-vfio" ];
    hardware.nvidia.open = lib.mkForce false;
    hardware.nvidia.package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.legacy_470;
    services.xserver.displayManager.startx.enable = true;
    vfio.enable = true;
  };

  # Graphics

  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];

  nixpkgs.config.nvidia.acceptLicense = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # VR

  services.monado.enable = true;

  programs.steam.package = pkgs.steam.override {
    extraProfile = ''
      unset TZ
      export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
    '';
  };

  # Use Manually Specified Location

  location.provider = "manual";
  location.latitude = config.lat;
  location.longitude = config.long;

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

        brightnessctl
        dmenu
        i3status
        lxappearance
        volumeicon
        xss-lock

     ];
    };
  };

  users.users.${config.user}.packages = with pkgs; [
    handbrake
    makemkv
  ];

  programs.i3lock.enable = true;

}
