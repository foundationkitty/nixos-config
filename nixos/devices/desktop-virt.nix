{ config, pkgs, lib, ... }:

# Variables

let
  gpuIDs = [
    config.graphicsPCI
    config.graphicsAudioPCI
  ];

in 

{
  options.vfio.enable = with lib;
    mkEnableOption "Configure the machine for VFIO";

  config = let cfg = config.vfio;
  in {
    boot = {
      initrd.kernelModules = [
        "vfio_pci"
        "vfio"
        "vfio_iommu_type1"
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];

      kernelParams = [
        "intel_iommu=on" "NVreg_EnableGpuFirmware=0"
      ] ++ lib.optional cfg.enable
        ("vfio-pci.ids=" + lib.concatStringsSep "," gpuIDs);
    };

    virtualisation.spiceUSBRedirection.enable = true;

  };
}

