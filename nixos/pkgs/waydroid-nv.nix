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

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.waydroid-nvidia.enable = true;
  services.waydroid-nvidia.refreshRate = 120;
  services.waydroid-nvidia.package = pkgs.waydroid-nvidia-full;

  virtualisation.lxc.enable = true;

  boot.kernelModules = [ "binder_linux" "udmabuf" ];
  boot.extraModprobeConfig = ''
    options binder_linux devices=binder,hwbinder,vndbinder
  '';

  networking.firewall.trustedInterfaces = [ "waydroid0" ];
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
  };
}
