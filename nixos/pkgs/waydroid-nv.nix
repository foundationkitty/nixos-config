{ config, pkgs, lib, ... }:

let
  sources = import ../lon.nix;

  wnvFlake = (import sources."flake-compat" {
    src = sources."waydroid-nvidia-nix";
  }).defaultNix;
in
{
  imports = [
    wnvFlake.nixosModules.waydroid-nvidia
  ];

  nixpkgs.overlays = [ wnvFlake.overlays.default ];

  services.waydroid-nvidia = {
    enable = true;
    package = pkgs.waydroid-nvidia-full;
    mode = "nvidia-prolapse";
    refreshRate = 120;
  };

  boot.kernelModules = [ "udmabuf" ];

  networking.firewall.extraCommands = ''
    iptables -I FORWARD -i waydroid0 -j ACCEPT
    iptables -I FORWARD -o waydroid0 -j ACCEPT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D FORWARD -i waydroid0 -j ACCEPT || true
    iptables -D FORWARD -o waydroid0 -j ACCEPT || true
  '';
}
