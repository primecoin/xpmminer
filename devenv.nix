{ pkgs, lib, ... }: {
  languages.c.enable = true;

  # 引入所有必要的构建工具和依赖
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

  # 使用 mkForce 解决 shell 定义冲突
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

    # 在 shell 启动时执行的命令
    shellHook = ''
      echo "Initializing cmake build in src directory..."
      mkdir -p build
      cd build
      cmake -DCMAKE_BUILD_TYPE=Release -DBUILDOPENCLMINER=OFF -DBUILDCUDAMINER=OFF ../src
      make
      echo "Build complete. You can find the results in the 'build' directory."
    '';
  });

  # git hooks 配置（保持你的原始配置）
  git-hooks.excludes = [ ".devenv" ];
  git-hooks.hooks = {
    clang-tidy.enable = true;
  };
}


