{ stdenv, fetchFromGitHub, kernel }:

stdenv.mkDerivation rec {
  pname = "panasonic-hbtn";
  version = "0";

  src = fetchFromGitHub {
    owner = "cyberpunkcoder";
    repo = "panasonic-hbtn";
    rev = "ee9f346";
    sha256 = "/QuBNwmxpIx+id+6paYjYvOztpSJIJmSwZKj2nC2y4U=";
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

