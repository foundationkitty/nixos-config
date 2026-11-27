{ stdenv, fetchFromGitHub, kernel, kernelModuleMakeFlags }:

let
  kdir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
in
stdenv.mkDerivation {
  pname = "panasonic-hbtn";
  version = "0-${kernel.version}";

  src = fetchFromGitHub {
    owner = "foundationkitty";
    repo = "panasonic-hbtn";
    rev = "d5c437e";
    sha256 = "sha256-yxPvNrZWl9+QfjoA/LMbv4TmJ+Gx0lW/AeEB4wQ+e8U=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernelModuleMakeFlags ++ [
    "KERNELRELEASE=${kernel.modDirVersion}"
    "INSTALL_MOD_PATH=${placeholder "out"}"
    "INSTALL_MOD_DIR=kernel/drivers/panasonic-hbtn"
  ];

  buildPhase = ''
    runHook preBuild
    local flagsArray=()
    concatTo flagsArray makeFlags
    make -C ${kdir} M=$(pwd) "''${flagsArray[@]}" modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    local flagsArray=()
    concatTo flagsArray makeFlags
    make -C ${kdir} M=$(pwd) "''${flagsArray[@]}" modules_install
    runHook postInstall
  '';
}
