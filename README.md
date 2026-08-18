xpmminer
========

Open-source primecoin(XPM) GPU & CPU miner (http://primecoin.io/). Only solo mining now available.

1 Requirements

- OS supported: Linux, Windows, and macOS 15 or newer
- NVIDIA GPU support: CUDA-capable GPUs supported by the installed CUDA toolkit and driver (Linux and Windows)
- AMD GPU support: Radeon RX 6000 series / RDNA2 or newer through ROCm/HIP (Linux)
- Apple GPU support: Apple silicon with an M1 GPU or newer through Metal (macOS 15 or newer)
- Legacy OpenCL support remains available on Linux and Windows

The Metal, HIP, and CUDA backends support both traditional `getblocktemplate` mining and WebSocket `blocktree.get_work`. Metal and HIP/CUDA on Linux were validated in this branch. The existing Windows CUDA and OpenCL build paths were not exercised as part of this work.

2 Performance

Metal, HIP, and CUDA automatically tune their sieve configuration for the detected GPU. Performance depends on the device, driver, and compiler. Use `-b` for the kernel and correctness suite, or `--mining-benchmark SECONDS` to measure the complete mining pipeline without network and submission latency.

3 Building

in linux see contrib/README.md

4 Usage

method 1
- Run official primecoin client with RPC support. Examples:<BR>
  primecoind -rpcuser=userName -rpcpassword=password<BR>
  primecoin-qt -rpcuser=userName -rpcpassword=password -server<BR>
  
- Run CPU or GPU miner,
./miner --url RPCaddress --user primecoinrpc --pass PASSWORD   --wallet youaddress
for other options, see --help

method 2
A rpc has been set up, `appalachians.primecoin.org:9915/api/jsonrpc`
Modify xpmminercpu (in linux cpu) / xpmminernv (in linux NVidia) / xpmminernv.bat (in windows NVidia)
by replacing the xpm address with your wallet address.
Then run these files. For example, in windows, run `.\xpmminernv.bat` in power shell.


5 Donations

BTC 17TQurzvatmsqZzGEe8jXnMDoiC4ACZjH7<BR>
LTC LdZcF4WejhC46DHfdyjvXomZzqQRy5xCj2<BR>
XPM Ac9ycgpEL4vzXRndS93Q7A7VGBHof1Jqzy
