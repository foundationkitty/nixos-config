{ lib, appimageTools, fetchurl, makeWrapper, flags ? [ ] }:

appimageTools.wrapType2 rec {
  pname = "greenlight";
  version = "2.4.2";

  src = fetchurl {
    url = "https://github.com/unknownskl/greenlight/releases/download/v${version}/Greenlight-${version}.AppImage";
    hash = "sha256-HOtWxLOzSEgFZfeECD46QiKteC3Zy5oKqJNN8HAzF3c=";
  };

  extraInstallCommands = lib.optionalString (flags != [ ]) ''
    source ${makeWrapper}/nix-support/setup-hook
    wrapProgram $out/bin/${pname} --add-flags ${lib.escapeShellArg (lib.concatStringsSep " " flags)}
  '';
}
