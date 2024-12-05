{ pkgs, lib, ... }: {
  languages.c.enable = true;

  # Introduce all necessary build tools and dependencies
  packages = [
    pkgs.cmake
    pkgs.ceedling
    pkgs.ncurses
    pkgs.curl
    pkgs.jansson
    pkgs.openssl
    pkgs.gmp5
    pkgs.gcc
    pkgs.gnumake
  ];

  # Use mkForce to resolve shell definition conflicts
  shell = lib.mkForce (pkgs.mkShell {
    buildInputs = [
      pkgs.cmake
      pkgs.ceedling
      pkgs.ncurses
      pkgs.curl
      pkgs.jansson
      pkgs.openssl
      pkgs.gmp5
      pkgs.gcc
      pkgs.gnumake
    ];

    # Commands executed when the shell starts
    shellHook = ''
      echo "Initializing cmake build in src directory..."
      mkdir -p build
      cd build
      cmake -DCMAKE_BUILD_TYPE=Release -DBUILDOPENCLMINER=OFF -DBUILDCUDAMINER=OFF ../src
      make
      echo "Build complete. You can find the results in the 'build' directory."
    '';
  });

  git-hooks.excludes = [ ".devenv" ];
  git-hooks.hooks = {
    clang-tidy.enable = true;
  };
}

