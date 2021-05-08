#!/bin/bash
set -e
VERSION="10.5-beta2"

# Linux static build

# gmp
cd /home/user/build/deps-linux
tar --lzip -xvf ../gmp-6.1.2.tar.lz
cd gmp-6.1.2
./configure --build corei7 --prefix=/home/user/install/x86_64-Linux --enable-cxx --enable-static --disable-shared 
make -j`nproc`
make install

# openssl
cd /home/user/build/deps-linux
tar -xzf ../openssl-1.0.0.tar.gz
cd openssl-1.0.0
./Configure --prefix=/home/user/install/x86_64-Linux
make -j`nproc`
make install

# zmq
cd /home/user/build/deps-linux
tar -xzf ../zeromq-4.3.1.tar.gz
cd zeromq-4.3.1
# disable glibc 2.25 'getrandom' usage for compatibility
sed -i 's/libzmq_cv_getrandom=\"yes\"/libzmq_cv_getrandom=\"no\"/' configure
./configure --prefix=/home/user/install/x86_64-Linux --enable-static --disable-shared 
make -j`nproc`
make install

# protobuf
cd /home/user/build/deps-linux
tar -xzf ../protobuf-cpp-3.6.1.tar.gz
cd protobuf-3.6.1
./configure --prefix=/home/user/install/x86_64-Linux --enable-static --disable-shared
make -j`nproc`
make install

# CLRX
mkdir $HOME/build/deps-linux/CLRX
cd $HOME/build/deps-linux/CLRX
cmake $HOME/build/CLRX-mirror -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/install/x86_64-Linux
make -j`nproc`
make install
rm $HOME/install/x86_64-Linux/lib64/libCLRX*.so*

# xpmclient
mkdir /home/user/build/xpmclient/x86_64-Linux
cd /home/user/build/xpmclient/x86_64-Linux
cmake ../src -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/home/user/install/x86_64-Linux \
  -DSTATIC_BUILD=ON \
  -DOpenCL_INCLUDE_DIR=/usr/local/cuda-11.2/include \
  -DOpenCL_LIBRARY=/usr/local/cuda-11.2/lib64/libOpenCL.so \
  -DCUDA_driver_LIBRARY=/usr/local/cuda-11.2/compat/libcuda.so
make -j`nproc`
strip xpmclient
strip xpmclientnv

# make AMD(OpenCL) distr
mkdir xpmclient-opencl-$VERSION-linux
cd xpmclient-opencl-$VERSION-linux
cp ../xpmclient .
cp ../../src/xpm/opencl/config.txt .
mkdir -p xpm/opencl
cp ../../src/xpm/opencl/generic_* xpm/opencl
cp ../../src/xpm/opencl/gcn_* xpm/opencl
cd ..
tar -czf xpmclient-opencl-$VERSION-linux.tar.gz xpmclient-opencl-$VERSION-linux

# make NVidia distr
mkdir xpmclient-cuda-$VERSION-linux
cd xpmclient-cuda-$VERSION-linux
cp ../xpmclientnv ./miner
echo "#/bin/bash" > xpmclientnv
echo "DIR=\$(dirname \"\$0\")" >> xpmclientnv
echo "LD_LIBRARY_PATH=\$DIR/. ./miner \$@" >> xpmclientnv
chmod +x xpmclientnv
cp ../../src/xpm/cuda/config.txt .
mkdir -p xpm/cuda
cp ../../src/xpm/cuda/*.cu xpm/cuda
cp /usr/local/cuda-11.2/lib64/libnvrtc.so.11.2 .
cp /usr/local/cuda-11.2/lib64/libnvrtc-builtins.so.11.2 .
cd ..
tar -czf xpmclient-cuda-$VERSION-linux.tar.gz xpmclient-cuda-$VERSION-linux

# Windows (MingGW) static build

# gmp
cd /home/user/build/deps-win32
tar --lzip -xvf ../gmp-6.1.2.tar.lz
cd gmp-6.1.2
./configure --host=x86_64-w64-mingw32 --build corei7 --prefix=/home/user/install/x86_64-w64-mingw32 --enable-cxx --enable-static --disable-shared
make -j`nproc`
make install

# sodium
cd /home/user/build/deps-win32
tar -xzf ../libsodium-1.0.17.tar.gz
cd libsodium-1.0.17
./configure --host=x86_64-w64-mingw32 --prefix=/home/user/install/x86_64-w64-mingw32 --enable-static --disable-shared 
make -j`nproc`
make install

# zmq (dll)
cd /home/user/build/deps-win32
tar -xzf ../zeromq-4.3.1.tar.gz
cd zeromq-4.3.1
./configure --host=x86_64-w64-mingw32 --prefix=/home/user/install/x86_64-w64-mingw32
make -j`nproc`
make install

# protobuf
cd /home/user/build/deps-win32
tar -xzf ../protobuf-cpp-3.6.1.tar.gz
cd protobuf-3.6.1
./configure --host=x86_64-w64-mingw32 --prefix=/home/user/install/x86_64-w64-mingw32 --enable-static --disable-shared
make -j`nproc`
make install

# CLRX
mkdir $HOME/build/deps-win32/CLRX
cd $HOME/build/deps-win32/CLRX
cmake $HOME/build/CLRX-mirror -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=$HOME/build/xpmclient/src/cmake/Toolchain-x86_64-w64-mingw32.cmake -DCMAKE_INSTALL_PREFIX=$HOME/install/x86_64-w64-mingw32
make -j`nproc`
make install
rm -f $HOME/install/x86_64-w64-mingw32/lib/libCLRX*.dll*

# xpmclient
mkdir /home/user/build/xpmclient/x86_64-w64-mingw32
cd /home/user/build/xpmclient/x86_64-w64-mingw32
cmake ../src -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=../src/cmake/Toolchain-x86_64-w64-mingw32.cmake \
  -DCMAKE_INSTALL_PREFIX=/home/user/install/x86_64-w64-mingw32 \
  -DSTATIC_BUILD=ON \
  -DProtobuf_PROTOC_EXECUTABLE=/home/user/install/x86_64-Linux/bin/protoc \
  -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda-win32 \
  -DOpenCL_INCLUDE_DIR=/usr/local/cuda-win32/include \
  -DOpenCL_LIBRARY=/usr/local/cuda-win32/lib/x64/OpenCL.lib
make -j`nproc` xpmclient xpmclientnv
x86_64-w64-mingw32-strip xpmclient.exe
x86_64-w64-mingw32-strip xpmclientnv.exe

# make AMD(OpenCL) distr
mkdir xpmclient-opencl-$VERSION-win64
cd xpmclient-opencl-$VERSION-win64
cp ../xpmclient.exe .
cp ../../src/xpm/opencl/config.txt .
mkdir -p xpm/opencl
cp ../../src/xpm/opencl/generic_* xpm/opencl
cp ../../src/xpm/opencl/gcn_* xpm/opencl
cp /usr/lib/gcc/x86_64-w64-mingw32/7.3-posix/libgcc_s_seh-1.dll .
cp /usr/lib/gcc/x86_64-w64-mingw32/7.3-posix/libstdc++-6.dll .
cp /usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll .
cp /home/user/install/x86_64-w64-mingw32/bin/libzmq.dll .
cd ..
zip -9 -r xpmclient-opencl-$VERSION-win64.zip xpmclient-opencl-$VERSION-win64

# make Nvidia distr
mkdir xpmclient-cuda-$VERSION-win64
cd xpmclient-cuda-$VERSION-win64
cp ../xpmclientnv.exe .
cp ../../src/xpm/cuda/config.txt .
mkdir -p xpm/cuda
cp ../../src/xpm/cuda/*.cu xpm/cuda
cp /usr/lib/gcc/x86_64-w64-mingw32/7.3-posix/libgcc_s_seh-1.dll .
cp /usr/lib/gcc/x86_64-w64-mingw32/7.3-posix/libstdc++-6.dll .
cp /usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll .
cp /home/user/install/x86_64-w64-mingw32/bin/libzmq.dll .
cp /usr/local/cuda-win32/bin/nvrtc64_112_0.dll .
cp /usr/local/cuda-win32/bin/nvrtc-builtins64_112.dll .
cd ..
zip -9 -r xpmclient-cuda-$VERSION-win64.zip xpmclient-cuda-$VERSION-win64

# Calculate SHA256 checksum
cd /home/user/build/xpmclient
sha256sum /home/user/build/xpmclient/x86_64-Linux/xpmclient-opencl-$VERSION-linux.tar.gz > xpmclient-$VERSION-sha256.txt
sha256sum /home/user/build/xpmclient/x86_64-Linux/xpmclient-cuda-$VERSION-linux.tar.gz >> xpmclient-$VERSION-sha256.txt
sha256sum /home/user/build/xpmclient/x86_64-w64-mingw32/xpmclient-opencl-$VERSION-win64.zip >> xpmclient-$VERSION-sha256.txt
sha256sum /home/user/build/xpmclient/x86_64-w64-mingw32/xpmclient-cuda-$VERSION-win64.zip >> xpmclient-$VERSION-sha256.txt
