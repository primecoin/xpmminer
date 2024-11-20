{ pkgs ? import <nixpkgs> {} }:

let
  ncurses = pkgs.ncurses;
  cmake = pkgs.cmake;
  curl = pkgs.curl;
  jansson = pkgs.jansson;
  openssl = pkgs.openssl;
  gmp = pkgs.gmp5;
  gcc = pkgs.gcc;
  gnumake = pkgs.gnumake;

in pkgs.stdenv.mkDerivation {
  name = "xpmminer-nixos-builder-with-cmake";
  src = ./src;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ ncurses cmake curl jansson openssl gmp gcc gnumake ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DBUILDOPENCLMINER=OFF"
    "-DBUILDCUDAMINER=OFF"
  ];

  enableParallelBuilding = true;

  installPhase = ''
    mkdir -p $out
    cp -r * $out/
  '';
  
  shellHook = ''
    echo "xpmminer nixos builder with cmake ready!"
  '';
}
