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
<<<<<<< HEAD
      mkdir build && cd build 
      cmake -DCMAKE_BUILD_TYPE=Release -DBUILDOPENCLMINER=OFF -DBUILDCUDAMINER=OFF ../src
      make
      cd ..
      echo "Build complete. You can find the results in the 'build' directory."
     # Set the shell prompt identifier
      export PS1="(devenv) \[\033[01;34m\]\w\[\033[00m\] \$ "
    '';
  });
  
=======
      mkdir -p build
      cd build
      cmake -DCMAKE_BUILD_TYPE=Release -DBUILDOPENCLMINER=OFF -DBUILDCUDAMINER=OFF ../src
      make
      echo "Build complete. You can find the results in the 'build' directory."
    '';
  });

>>>>>>> upstream/master
  git-hooks.excludes = [ ".devenv" ];
  git-hooks.hooks = {
    clang-tidy.enable = true;
  };
}
<<<<<<< HEAD
=======

>>>>>>> upstream/master
