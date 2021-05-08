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
tar -xzf ../openssl-1.1.0.tar.gz
cd openssl-1.1.0
./config --prefix=/home/user/install/x86_64-Linux no-shared
make -j`nproc`
make install

# curl
cd /home/user/build/deps-linux
tar -xzf ../curl-7.68.0.tar.gz
cd curl-7.68.0
./configure --prefix=/home/user/install/x86_64-Linux --enable-static --disable-shared 
make -j`nproc`
make install

# jansson
cd /home/user/build/deps-linux
tar -xzf ../jansson-2.11.tar.gz
cd jansson-2.11
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
mkdir /home/user/build/xpmminer/x86_64-Linux
cd /home/user/build/xpmminer/x86_64-Linux
cmake ../src -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/home/user/install/x86_64-Linux \
  -DSTATIC_BUILD=ON \
  -DOpenCL_INCLUDE_DIR=/usr/local/cuda-11.2/include \
  -DOpenCL_LIBRARY=/usr/local/cuda-11.2/lib64/libOpenCL.so \
  -DCUDA_driver_LIBRARY=/usr/local/cuda-11.2/compat/libcuda.so
make -j`nproc`


# make NVidia distr
mkdir xpmclient-cuda-$VERSION-linux
cd xpmclient-cuda-$VERSION-linux
cp ../xpmcuda ./miner
echo "#/bin/bash" > xpmclientnv
echo "DIR=\$(dirname \"\$0\")" >> xpmclientnv
echo "LD_LIBRARY_PATH=\$DIR/. ./miner \$@" >> xpmclientnv
chmod +x xpmcuda
cp ../../src/xpm/cuda/config.txt .
mkdir -p xpm/cuda
cp ../../src/xpm/cuda/*.cu xpm/cuda
cp /usr/local/cuda-11.2/lib64/libnvrtc.so.11.2 .
cp /usr/local/cuda-11.2/lib64/libnvrtc-builtins.so.11.2 .
cd ..
tar -czf xpmclient-cuda-$VERSION-linux.tar.gz xpmclient-cuda-$VERSION-linux

# Calculate SHA256 checksum
cd /home/user/build/xpmclient
sha256sum /home/user/build/xpmclient/x86_64-Linux/xpmclient-opencl-$VERSION-linux.tar.gz > xpmclient-$VERSION-sha256.txt
sha256sum /home/user/build/xpmclient/x86_64-Linux/xpmclient-cuda-$VERSION-linux.tar.gz >> xpmclient-$VERSION-sha256.txt
sha256sum /home/user/build/xpmclient/x86_64-w64-mingw32/xpmclient-opencl-$VERSION-win64.zip >> xpmclient-$VERSION-sha256.txt
sha256sum /home/user/build/xpmclient/x86_64-w64-mingw32/xpmclient-cuda-$VERSION-win64.zip >> xpmclient-$VERSION-sha256.txt
