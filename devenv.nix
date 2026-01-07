{ pkgs, ... }: {

  # 1. Install necessary packages
  packages = [
    pkgs.cmake
    pkgs.ceedling
    pkgs.ncurses
    pkgs.curl
    pkgs.jansson
    pkgs.openssl
    pkgs.gmp
    pkgs.gnumake
    pkgs.gcc
    pkgs.cudaPackages.cudatoolkit
    pkgs.rocmPackages.hipcc # ROCm/HIP compiler
    pkgs.rocmPackages.clr   # ROCm Common Language Runtime
  ];

  env = {
    # Ensure CMake uses GCC/G++ from Nix, not the system
    CC = "gcc";
    CXX = "g++";
    CUDA_STUB_LIB = "${pkgs.cudaPackages.cudatoolkit}/lib/stubs/libcuda.so";
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
    HIP_ROOT_DIR = "${pkgs.rocmPackages.hipcc}";
    ROCM_PATH = "${pkgs.rocmPackages.hipcc}";
  };

  scripts.build-miner.exec = ''
    echo "⚙️  Auto-configuring project (CUDA + HIP)..."
    cmake -S src -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILDCUDAMINER=ON \
      -DBUILDHIPMINER=ON \
      -DBUILDOPENCLMINER=OFF \
      -DCUDA_DRIVER_LIBRARY=$CUDA_STUB_LIB \
      -DHIP_ROOT_DIR=$HIP_ROOT_DIR
    echo "🔨 Starting multi-core build..."
    cmake --build build -j$(nproc)
  '';

  # Auto-detect CUDA drivers (NixOS/WSL2/Ubuntu)
  scripts.detect-cuda-drivers.exec = ''
    find_driver() {
      local path="$1"
      [ -d "$path" ] || return 1
      local res=$(find "$path" -maxdepth 1 -name "libcuda.so.*" -print -quit 2>/dev/null)
      [ -n "$res" ] || return 1
      echo "$res"
    }
    
    find_jit() {
      local path="$1"
      [ -d "$path" ] || return 1
      find "$path" -maxdepth 1 -name "libnvidia-ptxjitcompiler.so.*" -print -quit 2>/dev/null
    }

    IS_WSL2=false
    [ -f "/proc/sys/fs/binfmt_misc/WSLInterop" ] || grep -qi "microsoft" /proc/version 2>/dev/null && IS_WSL2=true
    
    IS_NIXOS=false
    [ -f "/etc/nixos/configuration.nix" ] || [ -n "$NIX_PATH" ] || [ -d "/run/opengl-driver" ] && IS_NIXOS=true

    FOUND_LIBCUDA=""
    FOUND_JIT=""

    # Priority: NixOS > WSL2 > Ubuntu > Fallback
    if [ "$IS_NIXOS" = "true" ] && [ -d "/run/opengl-driver/lib" ]; then
      res=$(find "/run/opengl-driver/lib" -maxdepth 1 \( -name "libcuda.so*" -type f -o -name "libcuda.so*" -type l \) 2>/dev/null | head -1)
      [ -n "$res" ] && FOUND_LIBCUDA=$(readlink -f "$res" 2>/dev/null || echo "$res")
      [ -n "$FOUND_LIBCUDA" ] && FOUND_JIT=$(find "/run/opengl-driver/lib" -maxdepth 1 \( -name "libnvidia-ptxjitcompiler.so*" -type f -o -name "libnvidia-ptxjitcompiler.so*" -type l \) 2>/dev/null | head -1)
      [ -n "$FOUND_JIT" ] && FOUND_JIT=$(readlink -f "$FOUND_JIT" 2>/dev/null || echo "$FOUND_JIT")
    fi

    if [ -z "$FOUND_LIBCUDA" ] && [ "$IS_WSL2" = "true" ]; then
      FOUND_LIBCUDA=$(find_driver "/usr/lib/wsl/lib")
      [ -n "$FOUND_LIBCUDA" ] && FOUND_JIT=$(find_jit "/usr/lib/wsl/lib")
      [ -z "$FOUND_LIBCUDA" ] && FOUND_LIBCUDA=$(find_driver "/usr/lib/x86_64-linux-gnu")
      [ -n "$FOUND_LIBCUDA" ] && [ -z "$FOUND_JIT" ] && FOUND_JIT=$(find_jit "/usr/lib/x86_64-linux-gnu")
    elif [ -z "$FOUND_LIBCUDA" ]; then
      FOUND_LIBCUDA=$(find_driver "/usr/lib/x86_64-linux-gnu")
      [ -n "$FOUND_LIBCUDA" ] && FOUND_JIT=$(find_jit "/usr/lib/x86_64-linux-gnu")
      [ -z "$FOUND_LIBCUDA" ] && FOUND_LIBCUDA=$(find_driver "/usr/lib/wsl/lib")
      [ -n "$FOUND_LIBCUDA" ] && [ -z "$FOUND_JIT" ] && FOUND_JIT=$(find_jit "/usr/lib/wsl/lib")
    fi

    [ -z "$FOUND_LIBCUDA" ] && FOUND_LIBCUDA=$(find_driver "/usr/lib64")
    [ -n "$FOUND_LIBCUDA" ] && [ -z "$FOUND_JIT" ] && FOUND_JIT=$(find_jit "/usr/lib64")

    [ -n "$FOUND_LIBCUDA" ] && {
      [ -n "$FOUND_JIT" ] && echo "$FOUND_LIBCUDA $FOUND_JIT" || echo "$FOUND_LIBCUDA"
    }
  '';

  enterShell = ''
    echo "=========================================="
    echo "🚀 xpmminer Development Environment"
    echo "=========================================="

    if [ -d "/run/opengl-driver/lib" ]; then
      export LD_LIBRARY_PATH="/run/opengl-driver/lib:''${LD_LIBRARY_PATH:-}"
      if [ -f "/run/opengl-driver/lib/libcuda.so.1" ] || [ -L "/run/opengl-driver/lib/libcuda.so.1" ]; then
        export LD_PRELOAD="/run/opengl-driver/lib/libcuda.so.1:''${LD_PRELOAD:-}"
        echo "✅ Using NixOS NVIDIA driver"
      fi
    else
      PRELOAD=$(detect-cuda-drivers)
      if [ -n "$PRELOAD" ]; then
        export LD_PRELOAD="$PRELOAD"
        FIRST_DRIVER=$(echo "$PRELOAD" | awk '{print $1}')
        echo "✅ Found System Driver: $FIRST_DRIVER"
        echo "$PRELOAD" | grep -q "libnvidia-ptxjitcompiler" && {
          echo "✅ Found JIT Compiler : $(echo "$PRELOAD" | awk '{print $2}')"
        }
        echo "💉 Auto-injected system drivers via LD_PRELOAD"
        [ -d "/usr/lib/wsl/lib" ] && export LD_LIBRARY_PATH="/usr/lib/wsl/lib:''${LD_LIBRARY_PATH:-}"
      else
        [ -f "/etc/nixos/configuration.nix" ] || [ -d "/run/opengl-driver" ] && {
          echo "⚠️  Warning: Could not find NVIDIA drivers."
          echo "    On NixOS, ensure hardware.nvidia is configured and run: sudo nixos-rebuild switch"
        } || echo "ℹ️  Note: NVIDIA drivers not found (normal for AMD/CPU miner)"
      fi
    fi

    export PATH="$CUDA_PATH/bin:$ROCM_PATH/bin:$PATH"

    echo ""
    echo "💡 Usage:"
    echo " Run 'build-miner'  -> Auto-start compilation"
  '';

  git-hooks.excludes = [ ".devenv" ];
}
