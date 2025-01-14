{ pkgs, lib, ... }: {
  languages.c.enable = true;

  # 引入所有必要的构建工具和依赖项
  packages = [
    pkgs.cmake
    pkgs.ncurses
    pkgs.curl
    pkgs.jansson
    pkgs.openssl
    pkgs.gmp
    pkgs.gmpxx
    pkgs.gcc10
    pkgs.gnumake
    pkgs.wget
    pkgs.gcc10Stdenv
    pkgs.cudaPackages_11_3.cudatoolkit
    pkgs.clinfo
    pkgs.cudaPackages.cuda_opencl
    pkgs.stdenv.cc.cc.lib
  ];

  env = {
    CC = "gcc";
    CXX = "g++";
    CXXFLAGS = "-std=c++11";
    CUDA_PATH = "${pkgs.cudaPackages_11_3.cudatoolkit}";
    OPENCL_PATH = "${pkgs.cudaPackages.cuda_opencl}";
  };
}

