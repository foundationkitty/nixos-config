{ config, pkgs, lib, ... }:

{

  # Use Manually Specified Location

  location.provider = "manual";
  location.latitude = config.lat;
  location.longitude = config.long;

  # Desktop Config

  displayManager.sddm.enable = true;
  displayManager.sddm.wayland.enable = true;
  
  desktopManager.plasma6 = {
    enable = true;
    extraPackages = with pkgs; [
      kdePackages.kcharselect
      kdePackages.kcolorchooser
      kdePackages.kolourpaint
      kdePackages.ksystemlog
      kdePackages.sddm-kcm
      kdiff3
      kdePackages.isoimagewriter
      kdePackages.partitionmanager
      wayland-utils
      wl-clipboard
    ];
  };
}
