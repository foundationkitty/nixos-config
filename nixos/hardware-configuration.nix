{ config, lib, pkgs, modulesPath, ... }:

let

  boot-uuid = config.boot-uuid;
  fs-uuid = config.fs-uuid;
  init-uuid = config.init-uuid;
  swap-uuid = config.swap-uuid;

in
{
  imports =
    [ 
      ./variables.nix
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "firewire_ohci" "usb_storage" "sd_mod" "sdhci_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/${config.fs-uuid}";
      fsType = "ext4";
    };

  boot.initrd.luks.devices."${config.init-uuid}".device = "/dev/disk/by-uuid/${config.init-uuid}";

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/${config.boot-uuid}";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/${config.swap-uuid}"; }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s25.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp2s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

