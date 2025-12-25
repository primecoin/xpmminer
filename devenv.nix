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
    pkgs.gcc      # Manually include GCC
    
    # GPU Dependencies
    pkgs.cudaPackages.cudatoolkit
    pkgs.rocmPackages.hipcc # ROCm/HIP compiler
    pkgs.rocmPackages.clr   # ROCm Common Language Runtime (dependency for some HIP versions)
  ];

  # 2. Automatically inject environment variables
  env = {
    # Manually set CC/CXX to ensure CMake finds the correct compiler
    CC = "gcc";
    CXX = "g++";

    # --- Key: Auto-locate CUDA stub library ---
    # This points to the stub library required for linking without a GPU driver installed
    CUDA_STUB_LIB = "${pkgs.cudaPackages.cudatoolkit}/lib/stubs/libcuda.so";
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";

    # --- Key: Auto-locate ROCm/HIP ---
    # Tells CMake where to find HIP, resolving "HIP not found" errors
    HIP_ROOT_DIR = "${pkgs.rocmPackages.hipcc}";
    ROCM_PATH = "${pkgs.rocmPackages.hipcc}";
  };

  # 3. Helper scripts (One-click commands)
  # Usage: just run 'build-miner' in the shell to start compiling
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

  # 4. Shell entry hook
  enterShell = ''
    echo "=========================================="
    echo "🚀 xpmminer Development Environment"
    echo "=========================================="
    
    # Add CUDA and HIP to PATH to ensure commands are found
    export PATH="$CUDA_PATH/bin:$ROCM_PATH/bin:$PATH"
    
    echo "✅ Environment variables injected:"
    echo "   CUDA Stub: $CUDA_STUB_LIB"
    echo "   HIP Root : $HIP_ROOT_DIR"
    echo ""
    echo "💡 Usage:"
    echo " Run 'build-miner'  -> Auto-start compilation"
  '';
  
  git-hooks.excludes = [ ".devenv" ];
}