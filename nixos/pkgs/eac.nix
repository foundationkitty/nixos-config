{ config, pkgs, lib, ... }:

let
  sources = import ../lon.nix;

  menuDefault = "normal";

  rpmPkgs =
    if lib.versionAtLeast pkgs.rpm.version "6" then
      pkgs
    else
      pkgs.extend (_: _: {
        rpm = (import (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/nixos-unstable) {
          config = config.nixpkgs.config;
        }).rpm;
      });

  kernel = config.system.build.eacnix.kernel;

  ublueKmods = names: pkgs.stdenvNoCC.mkDerivation {
    pname = "ublue-kmods";
    version = kernel.modDirVersion;
    dontUnpack = true;
    nativeBuildInputs = with pkgs; [ rpmPkgs.rpm cpio kmod xz ];
    installPhase = ''
      dst=$out/lib/modules/${kernel.modDirVersion}
      mkdir -p $dst
      for name in ${lib.escapeShellArgs names}; do
        rpms=(${kernel.akmods}/rpms/kmods/kmod-$name-${kernel.modDirVersion}-*.rpm)
        if [ ! -e "''${rpms[0]}" ]; then
          echo "no kmod-$name for ${kernel.modDirVersion} in Universal Blue's akmods image" >&2
          exit 1
        fi
        mkdir x-$name && (cd x-$name && rpm2cpio "''${rpms[0]}" | cpio -idm --quiet)
        found=
        for d in $(find x-$name -type d -path '*/lib/modules/${kernel.modDirVersion}'); do
          cp -a "$d/." $dst/
          found=1
        done
        [ -n "$found" ] || { echo "kmod-$name holds no modules for ${kernel.modDirVersion}" >&2; exit 1; }
      done

      for m in $(find $dst -name '*.ko*'); do
        [ "$(modinfo -F vermagic "$m" | cut -d' ' -f1)" = ${kernel.modDirVersion} ] \
          || { echo "$m isn't built for ${kernel.modDirVersion}" >&2; exit 1; }
        [ "$(modinfo -F sig_id "$m")" = "PKCS#7" ] \
          || { echo "$m isn't signed" >&2; exit 1; }
      done

      find $out -name '*.ko*' | sed -E 's/\.(xz|zst|gz)$//; s/$/.cer/' | xargs -r touch
    '';
    dontFixup = true;
    passthru.eacnix.vendorSigned = true;
  };

  esp = config.boot.loader.efi.efiSysMountPoint;
  grubCfg = "${esp}/EFI/${config.eacnix.boot.directory}/grub.cfg";
  menuEntries = pkgs.writeText "eac-grub-entries" (''
    menuentry 'NixOS' --id nixos-normal {
      chainloader /EFI/systemd/systemd-bootx64.efi
    }
    menuentry 'Windows 11' --id windows {
      search --no-floppy --file --set=root /EFI/Microsoft/Boot/bootmgfw.efi
      chainloader /EFI/Microsoft/Boot/bootmgfw.efi
    }
  '' + {
    eac = "";
    normal = "set default=nixos-normal\n";
    windows = "set default=windows\n";
  }.${menuDefault});
in
{
  imports = [
    ({ config, options, lib, pkgs, ... }@args:
      import "${sources.eacnix}/modules/eacnix.nix" (args // { pkgs = rpmPkgs; }))
  ];

  options.eac.active = lib.mkOption {
    type = lib.types.bool;
    default = false;
    internal = true;
    description = "True inside the eac specialisation (Bazzite's signed kernel).";
  };

  config = {
    nixpkgs.config.nvidia.acceptLicense = true;

    eacnix = {
      enable = true;
      vendor = "bazzite";
      nvidia.enable = true;
      nvidia.flavor = "open";
      boot.generations = 1;
      boot.timeout = config.bootLoaderTimeout;
      boot.install = false;
    };

    system.build.installBootLoader = lib.mkOverride 90 (pkgs.writeShellScript "install-lanzaboote-and-eacnix" ''
      ${config.boot.loader.external.installHook} "$@" || exit
      if ${config.system.build.eacnix.installCommand}; then
        ${pkgs.coreutils}/bin/cat ${menuEntries} >> ${lib.escapeShellArg grubCfg}
      else
        echo "warning: eacnix: the eac boot path was not updated (see above)." >&2
      fi
    '');

    specialisation.eac.configuration = {
      eac.active = true;

      hardware.xpadneo.enable = lib.mkForce false;
      boot.extraModulePackages = [ (ublueKmods [ "xpadneo" "v4l2loopback" ]) ];
      boot.kernelModules = [ "hid_xpadneo" ];
    };
  };
}
