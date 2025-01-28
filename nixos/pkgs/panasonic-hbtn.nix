{ stdenv, fetchFromGitHub, kernel }:

stdenv.mkDerivation rec {
  pname = "panasonic-hbtn";
  version = "0";

  src = fetchFromGitHub {
    owner = "foundationkitty";
    repo = "panasonic-hbtn";
    rev = "4534dec";
    sha256 = "9GDG+3EwiJQ+0FDliFe4AtB1LbQ+9UZozgCzx320F0s=";
  };

  KVER = "${kernel.modDirVersion}";

  buildPhase = ''
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build M=$(pwd) modules
  '';

  installPhase = ''
    mkdir -p $out/lib/modules/${KVER}/kernel/drivers/panasonic-hbtn/
    cp panasonic-hbtn.ko $out/lib/modules/${KVER}/kernel/drivers/panasonic-hbtn/
  '';

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "KERNELRELEASE=${kernel.modDirVersion}"
    "KERNEL_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ] ;
}

