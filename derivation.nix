{
  lib,
  stdenvNoCC,
  fetchurl,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "i-librarian";
  version = "5.11.3"; # Update this to the latest version string

  src = fetchurl {
    url = "https://github.com/mkucej/i-librarian-free/releases/download/${version}/I-Librarian-${version}-Linux.tar.xz";
    # Use lib.fakeHash to find the new one when you bump the version
    hash = "sha256-RhOnew6GYOE4XF1ezbhoPP2WDPLmFYcEiO+7Q6hK0ek=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r app classes config public "$out"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Reference manager, PDF manager and organizer";
    homepage = "https://i-librarian.net";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
