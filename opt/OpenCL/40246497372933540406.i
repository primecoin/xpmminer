# 1 "/tmp/comgr-7f7e55/input/CompileSource"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 390 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "/tmp/comgr-7f7e55/input/CompileSource" 2
typedef unsigned char uint8_t;
typedef unsigned int uint32_t;
typedef unsigned long uint64_t;

# 1 "/usr/local/share/xpmminer/sha256.h" 1
__constant uint ES[2] = { 0x00FF00FF, 0xFF00FF00 };
# 119 "/usr/local/share/xpmminer/sha256.h"
__constant uint K[] = {
  0x428a2f98U,
  0x71374491U,
  0xb5c0fbcfU,
  0xe9b5dba5U,
  0x3956c25bU,
  0x59f111f1U,
  0x923f82a4U,
  0xab1c5ed5U,
  0xd807aa98U,
  0x12835b01U,
  0x243185beU,
  0x550c7dc3U,
  0x72be5d74U,
  0x80deb1feU,
  0x9bdc06a7U,
  0xe49b69c1U,
  0xefbe4786U,
  0x0fc19dc6U,
  0x240ca1ccU,
  0x2de92c6fU,
  0x4a7484aaU,
  0x5cb0a9dcU,
  0x76f988daU,
  0x983e5152U,
  0xa831c66dU,
  0xb00327c8U,
  0xbf597fc7U,
  0xc6e00bf3U,
  0xd5a79147U,
  0x06ca6351U,
  0x14292967U,
  0x27b70a85U,
  0x2e1b2138U,
  0x4d2c6dfcU,
  0x53380d13U,
  0x650a7354U,
  0x766a0abbU,
  0x81c2c92eU,
  0x92722c85U,
  0xa2bfe8a1U,
  0xa81a664bU,
  0xc24b8b70U,
  0xc76c51a3U,
  0xd192e819U,
  0xd6990624U,
  0xf40e3585U,
  0x106aa070U,
  0x19a4c116U,
  0x1e376c08U,
  0x2748774cU,
  0x34b0bcb5U,
  0x391c0cb3U,
  0x4ed8aa4aU,
  0x5b9cca4fU,
  0x682e6ff3U,
  0x748f82eeU,
  0x78a5636fU,
  0x84c87814U,
  0x8cc70208U,
  0x90befffaU,
  0xa4506cebU,
  0xbef9a3f7U,
  0xc67178f2U,
  0x98c7e2a2U,
  0xfc08884dU,
  0xcd2a11aeU,
  0x510e527fU,
  0x9b05688cU,
  0xC3910C8EU,
  0xfb6feee7U,
  0x2a01a605U,
  0x0c2e12e0U,
  0x4498517BU,
  0x6a09e667U,
  0xa4ce148bU,
  0x95F61999U,
  0xc19bf174U,
  0xBB67AE85U,
  0x3C6EF372U,
  0xA54FF53AU,
  0x1F83D9ABU,
  0x5BE0CD19U,
  0x5C5C5C5CU,
  0x36363636U,
  0x80000000U,
  0x000003FFU,
  0x00000280U,
  0x000004a0U,
  0x00000300U
};
# 230 "/usr/local/share/xpmminer/sha256.h"
void sha256(uint4*restrict state0,uint4*restrict state1, const uint4 block0, const uint4 block1, const uint4 block2, const uint4 block3)
{
  uint4 S0 = *state0;
  uint4 S1 = *state1;
# 244 "/usr/local/share/xpmminer/sha256.h"
  uint4 W[4];

  W[ 0].x = block0.x;
  S1.w += (rotate(S1.x,26U) ^ rotate(S1.x,21U) ^ rotate(S1.x,7U)); S1.w += bitselect(S1.z,S1.y,S1.x); S1.w += W[0].x+ K[0]; S0.w += S1.w; S1.w += (rotate(S0.x,30U) ^ rotate(S0.x,19U) ^ rotate(S0.x,10U)); S1.w += bitselect(S0.z,S0.y,(S0.x^S0.z));;
  W[ 0].y = block0.y;
  S1.z += (rotate(S0.w,26U) ^ rotate(S0.w,21U) ^ rotate(S0.w,7U)); S1.z += bitselect(S1.y,S1.x,S0.w); S1.z += W[0].y+ K[1]; S0.z += S1.z; S1.z += (rotate(S1.w,30U) ^ rotate(S1.w,19U) ^ rotate(S1.w,10U)); S1.z += bitselect(S0.y,S0.x,(S1.w^S0.y));;
  W[ 0].z = block0.z;
  S1.y += (rotate(S0.z,26U) ^ rotate(S0.z,21U) ^ rotate(S0.z,7U)); S1.y += bitselect(S1.x,S0.w,S0.z); S1.y += W[0].z+ K[2]; S0.y += S1.y; S1.y += (rotate(S1.z,30U) ^ rotate(S1.z,19U) ^ rotate(S1.z,10U)); S1.y += bitselect(S0.x,S1.w,(S1.z^S0.x));;
  W[ 0].w = block0.w;
  S1.x += (rotate(S0.y,26U) ^ rotate(S0.y,21U) ^ rotate(S0.y,7U)); S1.x += bitselect(S0.w,S0.z,S0.y); S1.x += W[0].w+ K[3]; S0.x += S1.x; S1.x += (rotate(S1.y,30U) ^ rotate(S1.y,19U) ^ rotate(S1.y,10U)); S1.x += bitselect(S1.w,S1.z,(S1.y^S1.w));;

  W[ 1].x = block1.x;
  S0.w += (rotate(S0.x,26U) ^ rotate(S0.x,21U) ^ rotate(S0.x,7U)); S0.w += bitselect(S0.z,S0.y,S0.x); S0.w += W[1].x+ K[4]; S1.w += S0.w; S0.w += (rotate(S1.x,30U) ^ rotate(S1.x,19U) ^ rotate(S1.x,10U)); S0.w += bitselect(S1.z,S1.y,(S1.x^S1.z));;
  W[ 1].y = block1.y;
  S0.z += (rotate(S1.w,26U) ^ rotate(S1.w,21U) ^ rotate(S1.w,7U)); S0.z += bitselect(S0.y,S0.x,S1.w); S0.z += W[1].y+ K[5]; S1.z += S0.z; S0.z += (rotate(S0.w,30U) ^ rotate(S0.w,19U) ^ rotate(S0.w,10U)); S0.z += bitselect(S1.y,S1.x,(S0.w^S1.y));;
  W[ 1].z = block1.z;
  S0.y += (rotate(S1.z,26U) ^ rotate(S1.z,21U) ^ rotate(S1.z,7U)); S0.y += bitselect(S0.x,S1.w,S1.z); S0.y += W[1].z+ K[6]; S1.y += S0.y; S0.y += (rotate(S0.z,30U) ^ rotate(S0.z,19U) ^ rotate(S0.z,10U)); S0.y += bitselect(S1.x,S0.w,(S0.z^S1.x));;
  W[ 1].w = block1.w;
  S0.x += (rotate(S1.y,26U) ^ rotate(S1.y,21U) ^ rotate(S1.y,7U)); S0.x += bitselect(S1.w,S1.z,S1.y); S0.x += W[1].w+ K[7]; S1.x += S0.x; S0.x += (rotate(S0.y,30U) ^ rotate(S0.y,19U) ^ rotate(S0.y,10U)); S0.x += bitselect(S0.w,S0.z,(S0.y^S0.w));;

  W[ 2].x = block2.x;
  S1.w += (rotate(S1.x,26U) ^ rotate(S1.x,21U) ^ rotate(S1.x,7U)); S1.w += bitselect(S1.z,S1.y,S1.x); S1.w += W[2].x+ K[8]; S0.w += S1.w; S1.w += (rotate(S0.x,30U) ^ rotate(S0.x,19U) ^ rotate(S0.x,10U)); S1.w += bitselect(S0.z,S0.y,(S0.x^S0.z));;
  W[ 2].y = block2.y;
  S1.z += (rotate(S0.w,26U) ^ rotate(S0.w,21U) ^ rotate(S0.w,7U)); S1.z += bitselect(S1.y,S1.x,S0.w); S1.z += W[2].y+ K[9]; S0.z += S1.z; S1.z += (rotate(S1.w,30U) ^ rotate(S1.w,19U) ^ rotate(S1.w,10U)); S1.z += bitselect(S0.y,S0.x,(S1.w^S0.y));;
  W[ 2].z = block2.z;
  S1.y += (rotate(S0.z,26U) ^ rotate(S0.z,21U) ^ rotate(S0.z,7U)); S1.y += bitselect(S1.x,S0.w,S0.z); S1.y += W[2].z+ K[10]; S0.y += S1.y; S1.y += (rotate(S1.z,30U) ^ rotate(S1.z,19U) ^ rotate(S1.z,10U)); S1.y += bitselect(S0.x,S1.w,(S1.z^S0.x));;
  W[ 2].w = block2.w;
  S1.x += (rotate(S0.y,26U) ^ rotate(S0.y,21U) ^ rotate(S0.y,7U)); S1.x += bitselect(S0.w,S0.z,S0.y); S1.x += W[2].w+ K[11]; S0.x += S1.x; S1.x += (rotate(S1.y,30U) ^ rotate(S1.y,19U) ^ rotate(S1.y,10U)); S1.x += bitselect(S1.w,S1.z,(S1.y^S1.w));;

  W[ 3].x = block3.x;
  S0.w += (rotate(S0.x,26U) ^ rotate(S0.x,21U) ^ rotate(S0.x,7U)); S0.w += bitselect(S0.z,S0.y,S0.x); S0.w += W[3].x+ K[12]; S1.w += S0.w; S0.w += (rotate(S1.x,30U) ^ rotate(S1.x,19U) ^ rotate(S1.x,10U)); S0.w += bitselect(S1.z,S1.y,(S1.x^S1.z));;
  W[ 3].y = block3.y;
  S0.z += (rotate(S1.w,26U) ^ rotate(S1.w,21U) ^ rotate(S1.w,7U)); S0.z += bitselect(S0.y,S0.x,S1.w); S0.z += W[3].y+ K[13]; S1.z += S0.z; S0.z += (rotate(S0.w,30U) ^ rotate(S0.w,19U) ^ rotate(S0.w,10U)); S0.z += bitselect(S1.y,S1.x,(S0.w^S1.y));;
  W[ 3].z = block3.z;
  S0.y += (rotate(S1.z,26U) ^ rotate(S1.z,21U) ^ rotate(S1.z,7U)); S0.y += bitselect(S0.x,S1.w,S1.z); S0.y += W[3].z+ K[14]; S1.y += S0.y; S0.y += (rotate(S0.z,30U) ^ rotate(S0.z,19U) ^ rotate(S0.z,10U)); S0.y += bitselect(S1.x,S0.w,(S0.z^S1.x));;
  W[ 3].w = block3.w;
  S0.x += (rotate(S1.y,26U) ^ rotate(S1.y,21U) ^ rotate(S1.y,7U)); S0.x += bitselect(S1.w,S1.z,S1.y); S0.x += W[3].w+ K[76]; S1.x += S0.x; S0.x += (rotate(S0.y,30U) ^ rotate(S0.y,19U) ^ rotate(S0.y,10U)); S0.x += bitselect(S0.w,S0.z,(S0.y^S0.w));;

  W[ 0].x += (rotate(W[ 3].z,15U) ^ rotate(W[ 3].z,13U) ^ (W[ 3].z>>10U)) + W[ 2].y + (rotate(W[ 0].y,25U) ^ rotate(W[ 0].y,14U) ^ (W[ 0].y>>3U));
  S1.w += (rotate(S1.x,26U) ^ rotate(S1.x,21U) ^ rotate(S1.x,7U)); S1.w += bitselect(S1.z,S1.y,S1.x); S1.w += W[0].x+ K[15]; S0.w += S1.w; S1.w += (rotate(S0.x,30U) ^ rotate(S0.x,19U) ^ rotate(S0.x,10U)); S1.w += bitselect(S0.z,S0.y,(S0.x^S0.z));;

  W[ 0].y += (rotate(W[ 3].w,15U) ^ rotate(W[ 3].w,13U) ^ (W[ 3].w>>10U)) + W[ 2].z + (rotate(W[ 0].z,25U) ^ rotate(W[ 0].z,14U) ^ (W[ 0].z>>3U));
  S1.z += (rotate(S0.w,26U) ^ rotate(S0.w,21U) ^ rotate(S0.w,7U)); S1.z += bitselect(S1.y,S1.x,S0.w); S1.z += W[0].y+ K[16]; S0.z += S1.z; S1.z += (rotate(S1.w,30U) ^ rotate(S1.w,19U) ^ rotate(S1.w,10U)); S1.z += bitselect(S0.y,S0.x,(S1.w^S0.y));;

  W[ 0].z += (rotate(W[ 0].x,15U) ^ rotate(W[ 0].x,13U) ^ (W[ 0].x>>10U)) + W[ 2].w + (rotate(W[ 0].w,25U) ^ rotate(W[ 0].w,14U) ^ (W[ 0].w>>3U));
  S1.y += (rotate(S0.z,26U) ^ rotate(S0.z,21U) ^ rotate(S0.z,7U)); S1.y += bitselect(S1.x,S0.w,S0.z); S1.y += W[0].z+ K[17]; S0.y += S1.y; S1.y += (rotate(S1.z,30U) ^ rotate(S1.z,19U) ^ rotate(S1.z,10U)); S1.y += bitselect(S0.x,S1.w,(S1.z^S0.x));;

  W[ 0].w += (rotate(W[ 0].y,15U) ^ rotate(W[ 0].y,13U) ^ (W[ 0].y>>10U)) + W[ 3].x + (rotate(W[ 1].x,25U) ^ rotate(W[ 1].x,14U) ^ (W[ 1].x>>3U));
  S1.x += (rotate(S0.y,26U) ^ rotate(S0.y,21U) ^ rotate(S0.y,7U)); S1.x += bitselect(S0.w,S0.z,S0.y); S1.x += W[0].w+ K[18]; S0.x += S1.x; S1.x += (rotate(S1.y,30U) ^ rotate(S1.y,19U) ^ rotate(S1.y,10U)); S1.x += bitselect(S1.w,S1.z,(S1.y^S1.w));;

  W[ 1].x += (rotate(W[ 0].z,15U) ^ rotate(W[ 0].z,13U) ^ (W[ 0].z>>10U)) + W[ 3].y + (rotate(W[ 1].y,25U) ^ rotate(W[ 1].y,14U) ^ (W[ 1].y>>3U));
  S0.w += (rotate(S0.x,26U) ^ rotate(S0.x,21U) ^ rotate(S0.x,7U)); S0.w += bitselect(S0.z,S0.y,S0.x); S0.w += W[1].x+ K[19]; S1.w += S0.w; S0.w += (rotate(S1.x,30U) ^ rotate(S1.x,19U) ^ rotate(S1.x,10U)); S0.w += bitselect(S1.z,S1.y,(S1.x^S1.z));;

  W[ 1].y += (rotate(W[ 0].w,15U) ^ rotate(W[ 0].w,13U) ^ (W[ 0].w>>10U)) + W[ 3].z + (rotate(W[ 1].z,25U) ^ rotate(W[ 1].z,14U) ^ (W[ 1].z>>3U));
  S0.z += (rotate(S1.w,26U) ^ rotate(S1.w,21U) ^ rotate(S1.w,7U)); S0.z += bitselect(S0.y,S0.x,S1.w); S0.z += W[1].y+ K[20]; S1.z += S0.z; S0.z += (rotate(S0.w,30U) ^ rotate(S0.w,19U) ^ rotate(S0.w,10U)); S0.z += bitselect(S1.y,S1.x,(S0.w^S1.y));;

  W[ 1].z += (rotate(W[ 1].x,15U) ^ rotate(W[ 1].x,13U) ^ (W[ 1].x>>10U)) + W[ 3].w + (rotate(W[ 1].w,25U) ^ rotate(W[ 1].w,14U) ^ (W[ 1].w>>3U));
  S0.y += (rotate(S1.z,26U) ^ rotate(S1.z,21U) ^ rotate(S1.z,7U)); S0.y += bitselect(S0.x,S1.w,S1.z); S0.y += W[1].z+ K[21]; S1.y += S0.y; S0.y += (rotate(S0.z,30U) ^ rotate(S0.z,19U) ^ rotate(S0.z,10U)); S0.y += bitselect(S1.x,S0.w,(S0.z^S1.x));;

  W[ 1].w += (rotate(W[ 1].y,15U) ^ rotate(W[ 1].y,13U) ^ (W[ 1].y>>10U)) + W[ 0].x + (rotate(W[ 2].x,25U) ^ rotate(W[ 2].x,14U) ^ (W[ 2].x>>3U));
  S0.x += (rotate(S1.y,26U) ^ rotate(S1.y,21U) ^ rotate(S1.y,7U)); S0.x += bitselect(S1.w,S1.z,S1.y); S0.x += W[1].w+ K[22]; S1.x += S0.x; S0.x += (rotate(S0.y,30U) ^ rotate(S0.y,19U) ^ rotate(S0.y,10U)); S0.x += bitselect(S0.w,S0.z,(S0.y^S0.w));;

  W[ 2].x += (rotate(W[ 1].z,15U) ^ rotate(W[ 1].z,13U) ^ (W[ 1].z>>10U)) + W[ 0].y + (rotate(W[ 2].y,25U) ^ rotate(W[ 2].y,14U) ^ (W[ 2].y>>3U));
  S1.w += (rotate(S1.x,26U) ^ rotate(S1.x,21U) ^ rotate(S1.x,7U)); S1.w += bitselect(S1.z,S1.y,S1.x); S1.w += W[2].x+ K[23]; S0.w += S1.w; S1.w += (rotate(S0.x,30U) ^ rotate(S0.x,19U) ^ rotate(S0.x,10U)); S1.w += bitselect(S0.z,S0.y,(S0.x^S0.z));;

  W[ 2].y += (rotate(W[ 1].w,15U) ^ rotate(W[ 1].w,13U) ^ (W[ 1].w>>10U)) + W[ 0].z + (rotate(W[ 2].z,25U) ^ rotate(W[ 2].z,14U) ^ (W[ 2].z>>3U));
  S1.z += (rotate(S0.w,26U) ^ rotate(S0.w,21U) ^ rotate(S0.w,7U)); S1.z += bitselect(S1.y,S1.x,S0.w); S1.z += W[2].y+ K[24]; S0.z += S1.z; S1.z += (rotate(S1.w,30U) ^ rotate(S1.w,19U) ^ rotate(S1.w,10U)); S1.z += bitselect(S0.y,S0.x,(S1.w^S0.y));;

  W[ 2].z += (rotate(W[ 2].x,15U) ^ rotate(W[ 2].x,13U) ^ (W[ 2].x>>10U)) + W[ 0].w + (rotate(W[ 2].w,25U) ^ rotate(W[ 2].w,14U) ^ (W[ 2].w>>3U));
  S1.y += (rotate(S0.z,26U) ^ rotate(S0.z,21U) ^ rotate(S0.z,7U)); S1.y += bitselect(S1.x,S0.w,S0.z); S1.y += W[2].z+ K[25]; S0.y += S1.y; S1.y += (rotate(S1.z,30U) ^ rotate(S1.z,19U) ^ rotate(S1.z,10U)); S1.y += bitselect(S0.x,S1.w,(S1.z^S0.x));;

  W[ 2].w += (rotate(W[ 2].y,15U) ^ rotate(W[ 2].y,13U) ^ (W[ 2].y>>10U)) + W[ 1].x + (rotate(W[ 3].x,25U) ^ rotate(W[ 3].x,14U) ^ (W[ 3].x>>3U));
  S1.x += (rotate(S0.y,26U) ^ rotate(S0.y,21U) ^ rotate(S0.y,7U)); S1.x += bitselect(S0.w,S0.z,S0.y); S1.x += W[2].w+ K[26]; S0.x += S1.x; S1.x += (rotate(S1.y,30U) ^ rotate(S1.y,19U) ^ rotate(S1.y,10U)); S1.x += bitselect(S1.w,S1.z,(S1.y^S1.w));;

  W[ 3].x += (rotate(W[ 2].z,15U) ^ rotate(W[ 2].z,13U) ^ (W[ 2].z>>10U)) + W[ 1].y + (rotate(W[ 3].y,25U) ^ rotate(W[ 3].y,14U) ^ (W[ 3].y>>3U));
  S0.w += (rotate(S0.x,26U) ^ rotate(S0.x,21U) ^ rotate(S0.x,7U)); S0.w += bitselect(S0.z,S0.y,S0.x); S0.w += W[3].x+ K[27]; S1.w += S0.w; S0.w += (rotate(S1.x,30U) ^ rotate(S1.x,19U) ^ rotate(S1.x,10U)); S0.w += bitselect(S1.z,S1.y,(S1.x^S1.z));;

  W[ 3].y += (rotate(W[ 2].w,15U) ^ rotate(W[ 2].w,13U) ^ (W[ 2].w>>10U)) + W[ 1].z + (rotate(W[ 3].z,25U) ^ rotate(W[ 3].z,14U) ^ (W[ 3].z>>3U));
  S0.z += (rotate(S1.w,26U) ^ rotate(S1.w,21U) ^ rotate(S1.w,7U)); S0.z += bitselect(S0.y,S0.x,S1.w); S0.z += W[3].y+ K[28]; S1.z += S0.z; S0.z += (rotate(S0.w,30U) ^ rotate(S0.w,19U) ^ rotate(S0.w,10U)); S0.z += bitselect(S1.y,S1.x,(S0.w^S1.y));;

  W[ 3].z += (rotate(W[ 3].x,15U) ^ rotate(W[ 3].x,13U) ^ (W[ 3].x>>10U)) + W[ 1].w + (rotate(W[ 3].w,25U) ^ rotate(W[ 3].w,14U) ^ (W[ 3].w>>3U));
  S0.y += (rotate(S1.z,26U) ^ rotate(S1.z,21U) ^ rotate(S1.z,7U)); S0.y += bitselect(S0.x,S1.w,S1.z); S0.y += W[3].z+ K[29]; S1.y += S0.y; S0.y += (rotate(S0.z,30U) ^ rotate(S0.z,19U) ^ rotate(S0.z,10U)); S0.y += bitselect(S1.x,S0.w,(S0.z^S1.x));;

  W[ 3].w += (rotate(W[ 3].y,15U) ^ rotate(W[ 3].y,13U) ^ (W[ 3].y>>10U)) + W[ 2].x + (rotate(W[ 0].x,25U) ^ rotate(W[ 0].x,14U) ^ (W[ 0].x>>3U));
  S0.x += (rotate(S1.y,26U) ^ rotate(S1.y,21U) ^ rotate(S1.y,7U)); S0.x += bitselect(S1.w,S1.z,S1.y); S0.x += W[3].w+ K[30]; S1.x += S0.x; S0.x += (rotate(S0.y,30U) ^ rotate(S0.y,19U) ^ rotate(S0.y,10U)); S0.x += bitselect(S0.w,S0.z,(S0.y^S0.w));;

  W[ 0].x += (rotate(W[ 3].z,15U) ^ rotate(W[ 3].z,13U) ^ (W[ 3].z>>10U)) + W[ 2].y + (rotate(W[ 0].y,25U) ^ rotate(W[ 0].y,14U) ^ (W[ 0].y>>3U));
  S1.w += (rotate(S1.x,26U) ^ rotate(S1.x,21U) ^ rotate(S1.x,7U)); S1.w += bitselect(S1.z,S1.y,S1.x); S1.w += W[0].x+ K[31]; S0.w += S1.w; S1.w += (rotate(S0.x,30U) ^ rotate(S0.x,19U) ^ rotate(S0.x,10U)); S1.w += bitselect(S0.z,S0.y,(S0.x^S0.z));;

  W[ 0].y += (rotate(W[ 3].w,15U) ^ rotate(W[ 3].w,13U) ^ (W[ 3].w>>10U)) + W[ 2].z + (rotate(W[ 0].z,25U) ^ rotate(W[ 0].z,14U) ^ (W[ 0].z>>3U));
  S1.z += (rotate(S0.w,26U) ^ rotate(S0.w,21U) ^ rotate(S0.w,7U)); S1.z += bitselect(S1.y,S1.x,S0.w); S1.z += W[0].y+ K[32]; S0.z += S1.z; S1.z += (rotate(S1.w,30U) ^ rotate(S1.w,19U) ^ rotate(S1.w,10U)); S1.z += bitselect(S0.y,S0.x,(S1.w^S0.y));;

  W[ 0].z += (rotate(W[ 0].x,15U) ^ rotate(W[ 0].x,13U) ^ (W[ 0].x>>10U)) + W[ 2].w + (rotate(W[ 0].w,25U) ^ rotate(W[ 0].w,14U) ^ (W[ 0].w>>3U));
  S1.y += (rotate(S0.z,26U) ^ rotate(S0.z,21U) ^ rotate(S0.z,7U)); S1.y += bitselect(S1.x,S0.w,S0.z); S1.y += W[0].z+ K[33]; S0.y += S1.y; S1.y += (rotate(S1.z,30U) ^ rotate(S1.z,19U) ^ rotate(S1.z,10U)); S1.y += bitselect(S0.x,S1.w,(S1.z^S0.x));;

  W[ 0].w += (rotate(W[ 0].y,15U) ^ rotate(W[ 0].y,13U) ^ (W[ 0].y>>10U)) + W[ 3].x + (rotate(W[ 1].x,25U) ^ rotate(W[ 1].x,14U) ^ (W[ 1].x>>3U));
  S1.x += (rotate(S0.y,26U) ^ rotate(S0.y,21U) ^ rotate(S0.y,7U)); S1.x += bitselect(S0.w,S0.z,S0.y); S1.x += W[0].w+ K[34]; S0.x += S1.x; S1.x += (rotate(S1.y,30U) ^ rotate(S1.y,19U) ^ rotate(S1.y,10U)); S1.x += bitselect(S1.w,S1.z,(S1.y^S1.w));;

  W[ 1].x += (rotate(W[ 0].z,15U) ^ rotate(W[ 0].z,13U) ^ (W[ 0].z>>10U)) + W[ 3].y + (rotate(W[ 1].y,25U) ^ rotate(W[ 1].y,14U) ^ (W[ 1].y>>3U));
  S0.w += (rotate(S0.x,26U) ^ rotate(S0.x,21U) ^ rotate(S0.x,7U)); S0.w += bitselect(S0.z,S0.y,S0.x); S0.w += W[1].x+ K[35]; S1.w += S0.w; S0.w += (rotate(S1.x,30U) ^ rotate(S1.x,19U) ^ rotate(S1.x,10U)); S0.w += bitselect(S1.z,S1.y,(S1.x^S1.z));;

  W[ 1].y += (rotate(W[ 0].w,15U) ^ rotate(W[ 0].w,13U) ^ (W[ 0].w>>10U)) + W[ 3].z + (rotate(W[ 1].z,25U) ^ rotate(W[ 1].z,14U) ^ (W[ 1].z>>3U));
  S0.z += (rotate(S1.w,26U) ^ rotate(S1.w,21U) ^ rotate(S1.w,7U)); S0.z += bitselect(S0.y,S0.x,S1.w); S0.z += W[1].y+ K[36]; S1.z += S0.z; S0.z += (rotate(S0.w,30U) ^ rotate(S0.w,19U) ^ rotate(S0.w,10U)); S0.z += bitselect(S1.y,S1.x,(S0.w^S1.y));;

  W[ 1].z += (rotate(W[ 1].x,15U) ^ rotate(W[ 1].x,13U) ^ (W[ 1].x>>10U)) + W[ 3].w + (rotate(W[ 1].w,25U) ^ rotate(W[ 1].w,14U) ^ (W[ 1].w>>3U));
  S0.y += (rotate(S1.z,26U) ^ rotate(S1.z,21U) ^ rotate(S1.z,7U)); S0.y += bitselect(S0.x,S1.w,S1.z); S0.y += W[1].z+ K[37]; S1.y += S0.y; S0.y += (rotate(S0.z,30U) ^ rotate(S0.z,19U) ^ rotate(S0.z,10U)); S0.y += bitselect(S1.x,S0.w,(S0.z^S1.x));;

  W[ 1].w += (rotate(W[ 1].y,15U) ^ rotate(W[ 1].y,13U) ^ (W[ 1].y>>10U)) + W[ 0].x + (rotate(W[ 2].x,25U) ^ rotate(W[ 2].x,14U) ^ (W[ 2].x>>3U));
  S0.x += (rotate(S1.y,26U) ^ rotate(S1.y,21U) ^ rotate(S1.y,7U)); S0.x += bitselect(S1.w,S1.z,S1.y); S0.x += W[1].w+ K[38]; S1.x += S0.x; S0.x += (rotate(S0.y,30U) ^ rotate(S0.y,19U) ^ rotate(S0.y,10U)); S0.x += bitselect(S0.w,S0.z,(S0.y^S0.w));;

  W[ 2].x += (rotate(W[ 1].z,15U) ^ rotate(W[ 1].z,13U) ^ (W[ 1].z>>10U)) + W[ 0].y + (rotate(W[ 2].y,25U) ^ rotate(W[ 2].y,14U) ^ (W[ 2].y>>3U));
  S1.w += (rotate(S1.x,26U) ^ rotate(S1.x,21U) ^ rotate(S1.x,7U)); S1.w += bitselect(S1.z,S1.y,S1.x); S1.w += W[2].x+ K[39]; S0.w += S1.w; S1.w += (rotate(S0.x,30U) ^ rotate(S0.x,19U) ^ rotate(S0.x,10U)); S1.w += bitselect(S0.z,S0.y,(S0.x^S0.z));;

  W[ 2].y += (rotate(W[ 1].w,15U) ^ rotate(W[ 1].w,13U) ^ (W[ 1].w>>10U)) + W[ 0].z + (rotate(W[ 2].z,25U) ^ rotate(W[ 2].z,14U) ^ (W[ 2].z>>3U));
  S1.z += (rotate(S0.w,26U) ^ rotate(S0.w,21U) ^ rotate(S0.w,7U)); S1.z += bitselect(S1.y,S1.x,S0.w); S1.z += W[2].y+ K[40]; S0.z += S1.z; S1.z += (rotate(S1.w,30U) ^ rotate(S1.w,19U) ^ rotate(S1.w,10U)); S1.z += bitselect(S0.y,S0.x,(S1.w^S0.y));;

  W[ 2].z += (rotate(W[ 2].x,15U) ^ rotate(W[ 2].x,13U) ^ (W[ 2].x>>10U)) + W[ 0].w + (rotate(W[ 2].w,25U) ^ rotate(W[ 2].w,14U) ^ (W[ 2].w>>3U));
  S1.y += (rotate(S0.z,26U) ^ rotate(S0.z,21U) ^ rotate(S0.z,7U)); S1.y += bitselect(S1.x,S0.w,S0.z); S1.y += W[2].z+ K[41]; S0.y += S1.y; S1.y += (rotate(S1.z,30U) ^ rotate(S1.z,19U) ^ rotate(S1.z,10U)); S1.y += bitselect(S0.x,S1.w,(S1.z^S0.x));;

  W[ 2].w += (rotate(W[ 2].y,15U) ^ rotate(W[ 2].y,13U) ^ (W[ 2].y>>10U)) + W[ 1].x + (rotate(W[ 3].x,25U) ^ rotate(W[ 3].x,14U) ^ (W[ 3].x>>3U));
  S1.x += (rotate(S0.y,26U) ^ rotate(S0.y,21U) ^ rotate(S0.y,7U)); S1.x += bitselect(S0.w,S0.z,S0.y); S1.x += W[2].w+ K[42]; S0.x += S1.x; S1.x += (rotate(S1.y,30U) ^ rotate(S1.y,19U) ^ rotate(S1.y,10U)); S1.x += bitselect(S1.w,S1.z,(S1.y^S1.w));;

  W[ 3].x += (rotate(W[ 2].z,15U) ^ rotate(W[ 2].z,13U) ^ (W[ 2].z>>10U)) + W[ 1].y + (rotate(W[ 3].y,25U) ^ rotate(W[ 3].y,14U) ^ (W[ 3].y>>3U));
  S0.w += (rotate(S0.x,26U) ^ rotate(S0.x,21U) ^ rotate(S0.x,7U)); S0.w += bitselect(S0.z,S0.y,S0.x); S0.w += W[3].x+ K[43]; S1.w += S0.w; S0.w += (rotate(S1.x,30U) ^ rotate(S1.x,19U) ^ rotate(S1.x,10U)); S0.w += bitselect(S1.z,S1.y,(S1.x^S1.z));;

  W[ 3].y += (rotate(W[ 2].w,15U) ^ rotate(W[ 2].w,13U) ^ (W[ 2].w>>10U)) + W[ 1].z + (rotate(W[ 3].z,25U) ^ rotate(W[ 3].z,14U) ^ (W[ 3].z>>3U));
  S0.z += (rotate(S1.w,26U) ^ rotate(S1.w,21U) ^ rotate(S1.w,7U)); S0.z += bitselect(S0.y,S0.x,S1.w); S0.z += W[3].y+ K[44]; S1.z += S0.z; S0.z += (rotate(S0.w,30U) ^ rotate(S0.w,19U) ^ rotate(S0.w,10U)); S0.z += bitselect(S1.y,S1.x,(S0.w^S1.y));;

  W[ 3].z += (rotate(W[ 3].x,15U) ^ rotate(W[ 3].x,13U) ^ (W[ 3].x>>10U)) + W[ 1].w + (rotate(W[ 3].w,25U) ^ rotate(W[ 3].w,14U) ^ (W[ 3].w>>3U));
  S0.y += (rotate(S1.z,26U) ^ rotate(S1.z,21U) ^ rotate(S1.z,7U)); S0.y += bitselect(S0.x,S1.w,S1.z); S0.y += W[3].z+ K[45]; S1.y += S0.y; S0.y += (rotate(S0.z,30U) ^ rotate(S0.z,19U) ^ rotate(S0.z,10U)); S0.y += bitselect(S1.x,S0.w,(S0.z^S1.x));;

  W[ 3].w += (rotate(W[ 3].y,15U) ^ rotate(W[ 3].y,13U) ^ (W[ 3].y>>10U)) + W[ 2].x + (rotate(W[ 0].x,25U) ^ rotate(W[ 0].x,14U) ^ (W[ 0].x>>3U));
  S0.x += (rotate(S1.y,26U) ^ rotate(S1.y,21U) ^ rotate(S1.y,7U)); S0.x += bitselect(S1.w,S1.z,S1.y); S0.x += W[3].w+ K[46]; S1.x += S0.x; S0.x += (rotate(S0.y,30U) ^ rotate(S0.y,19U) ^ rotate(S0.y,10U)); S0.x += bitselect(S0.w,S0.z,(S0.y^S0.w));;

  W[ 0].x += (rotate(W[ 3].z,15U) ^ rotate(W[ 3].z,13U) ^ (W[ 3].z>>10U)) + W[ 2].y + (rotate(W[ 0].y,25U) ^ rotate(W[ 0].y,14U) ^ (W[ 0].y>>3U));
  S1.w += (rotate(S1.x,26U) ^ rotate(S1.x,21U) ^ rotate(S1.x,7U)); S1.w += bitselect(S1.z,S1.y,S1.x); S1.w += W[0].x+ K[47]; S0.w += S1.w; S1.w += (rotate(S0.x,30U) ^ rotate(S0.x,19U) ^ rotate(S0.x,10U)); S1.w += bitselect(S0.z,S0.y,(S0.x^S0.z));;

  W[ 0].y += (rotate(W[ 3].w,15U) ^ rotate(W[ 3].w,13U) ^ (W[ 3].w>>10U)) + W[ 2].z + (rotate(W[ 0].z,25U) ^ rotate(W[ 0].z,14U) ^ (W[ 0].z>>3U));
  S1.z += (rotate(S0.w,26U) ^ rotate(S0.w,21U) ^ rotate(S0.w,7U)); S1.z += bitselect(S1.y,S1.x,S0.w); S1.z += W[0].y+ K[48]; S0.z += S1.z; S1.z += (rotate(S1.w,30U) ^ rotate(S1.w,19U) ^ rotate(S1.w,10U)); S1.z += bitselect(S0.y,S0.x,(S1.w^S0.y));;

  W[ 0].z += (rotate(W[ 0].x,15U) ^ rotate(W[ 0].x,13U) ^ (W[ 0].x>>10U)) + W[ 2].w + (rotate(W[ 0].w,25U) ^ rotate(W[ 0].w,14U) ^ (W[ 0].w>>3U));
  S1.y += (rotate(S0.z,26U) ^ rotate(S0.z,21U) ^ rotate(S0.z,7U)); S1.y += bitselect(S1.x,S0.w,S0.z); S1.y += W[0].z+ K[49]; S0.y += S1.y; S1.y += (rotate(S1.z,30U) ^ rotate(S1.z,19U) ^ rotate(S1.z,10U)); S1.y += bitselect(S0.x,S1.w,(S1.z^S0.x));;

  W[ 0].w += (rotate(W[ 0].y,15U) ^ rotate(W[ 0].y,13U) ^ (W[ 0].y>>10U)) + W[ 3].x + (rotate(W[ 1].x,25U) ^ rotate(W[ 1].x,14U) ^ (W[ 1].x>>3U));
  S1.x += (rotate(S0.y,26U) ^ rotate(S0.y,21U) ^ rotate(S0.y,7U)); S1.x += bitselect(S0.w,S0.z,S0.y); S1.x += W[0].w+ K[50]; S0.x += S1.x; S1.x += (rotate(S1.y,30U) ^ rotate(S1.y,19U) ^ rotate(S1.y,10U)); S1.x += bitselect(S1.w,S1.z,(S1.y^S1.w));;

  W[ 1].x += (rotate(W[ 0].z,15U) ^ rotate(W[ 0].z,13U) ^ (W[ 0].z>>10U)) + W[ 3].y + (rotate(W[ 1].y,25U) ^ rotate(W[ 1].y,14U) ^ (W[ 1].y>>3U));
  S0.w += (rotate(S0.x,26U) ^ rotate(S0.x,21U) ^ rotate(S0.x,7U)); S0.w += bitselect(S0.z,S0.y,S0.x); S0.w += W[1].x+ K[51]; S1.w += S0.w; S0.w += (rotate(S1.x,30U) ^ rotate(S1.x,19U) ^ rotate(S1.x,10U)); S0.w += bitselect(S1.z,S1.y,(S1.x^S1.z));;

  W[ 1].y += (rotate(W[ 0].w,15U) ^ rotate(W[ 0].w,13U) ^ (W[ 0].w>>10U)) + W[ 3].z + (rotate(W[ 1].z,25U) ^ rotate(W[ 1].z,14U) ^ (W[ 1].z>>3U));
  S0.z += (rotate(S1.w,26U) ^ rotate(S1.w,21U) ^ rotate(S1.w,7U)); S0.z += bitselect(S0.y,S0.x,S1.w); S0.z += W[1].y+ K[52]; S1.z += S0.z; S0.z += (rotate(S0.w,30U) ^ rotate(S0.w,19U) ^ rotate(S0.w,10U)); S0.z += bitselect(S1.y,S1.x,(S0.w^S1.y));;

  W[ 1].z += (rotate(W[ 1].x,15U) ^ rotate(W[ 1].x,13U) ^ (W[ 1].x>>10U)) + W[ 3].w + (rotate(W[ 1].w,25U) ^ rotate(W[ 1].w,14U) ^ (W[ 1].w>>3U));
  S0.y += (rotate(S1.z,26U) ^ rotate(S1.z,21U) ^ rotate(S1.z,7U)); S0.y += bitselect(S0.x,S1.w,S1.z); S0.y += W[1].z+ K[53]; S1.y += S0.y; S0.y += (rotate(S0.z,30U) ^ rotate(S0.z,19U) ^ rotate(S0.z,10U)); S0.y += bitselect(S1.x,S0.w,(S0.z^S1.x));;

  W[ 1].w += (rotate(W[ 1].y,15U) ^ rotate(W[ 1].y,13U) ^ (W[ 1].y>>10U)) + W[ 0].x + (rotate(W[ 2].x,25U) ^ rotate(W[ 2].x,14U) ^ (W[ 2].x>>3U));
  S0.x += (rotate(S1.y,26U) ^ rotate(S1.y,21U) ^ rotate(S1.y,7U)); S0.x += bitselect(S1.w,S1.z,S1.y); S0.x += W[1].w+ K[54]; S1.x += S0.x; S0.x += (rotate(S0.y,30U) ^ rotate(S0.y,19U) ^ rotate(S0.y,10U)); S0.x += bitselect(S0.w,S0.z,(S0.y^S0.w));;

  W[ 2].x += (rotate(W[ 1].z,15U) ^ rotate(W[ 1].z,13U) ^ (W[ 1].z>>10U)) + W[ 0].y + (rotate(W[ 2].y,25U) ^ rotate(W[ 2].y,14U) ^ (W[ 2].y>>3U));
  S1.w += (rotate(S1.x,26U) ^ rotate(S1.x,21U) ^ rotate(S1.x,7U)); S1.w += bitselect(S1.z,S1.y,S1.x); S1.w += W[2].x+ K[55]; S0.w += S1.w; S1.w += (rotate(S0.x,30U) ^ rotate(S0.x,19U) ^ rotate(S0.x,10U)); S1.w += bitselect(S0.z,S0.y,(S0.x^S0.z));;

  W[ 2].y += (rotate(W[ 1].w,15U) ^ rotate(W[ 1].w,13U) ^ (W[ 1].w>>10U)) + W[ 0].z + (rotate(W[ 2].z,25U) ^ rotate(W[ 2].z,14U) ^ (W[ 2].z>>3U));
  S1.z += (rotate(S0.w,26U) ^ rotate(S0.w,21U) ^ rotate(S0.w,7U)); S1.z += bitselect(S1.y,S1.x,S0.w); S1.z += W[2].y+ K[56]; S0.z += S1.z; S1.z += (rotate(S1.w,30U) ^ rotate(S1.w,19U) ^ rotate(S1.w,10U)); S1.z += bitselect(S0.y,S0.x,(S1.w^S0.y));;

  W[ 2].z += (rotate(W[ 2].x,15U) ^ rotate(W[ 2].x,13U) ^ (W[ 2].x>>10U)) + W[ 0].w + (rotate(W[ 2].w,25U) ^ rotate(W[ 2].w,14U) ^ (W[ 2].w>>3U));
  S1.y += (rotate(S0.z,26U) ^ rotate(S0.z,21U) ^ rotate(S0.z,7U)); S1.y += bitselect(S1.x,S0.w,S0.z); S1.y += W[2].z+ K[57]; S0.y += S1.y; S1.y += (rotate(S1.z,30U) ^ rotate(S1.z,19U) ^ rotate(S1.z,10U)); S1.y += bitselect(S0.x,S1.w,(S1.z^S0.x));;

  W[ 2].w += (rotate(W[ 2].y,15U) ^ rotate(W[ 2].y,13U) ^ (W[ 2].y>>10U)) + W[ 1].x + (rotate(W[ 3].x,25U) ^ rotate(W[ 3].x,14U) ^ (W[ 3].x>>3U));
  S1.x += (rotate(S0.y,26U) ^ rotate(S0.y,21U) ^ rotate(S0.y,7U)); S1.x += bitselect(S0.w,S0.z,S0.y); S1.x += W[2].w+ K[58]; S0.x += S1.x; S1.x += (rotate(S1.y,30U) ^ rotate(S1.y,19U) ^ rotate(S1.y,10U)); S1.x += bitselect(S1.w,S1.z,(S1.y^S1.w));;

  W[ 3].x += (rotate(W[ 2].z,15U) ^ rotate(W[ 2].z,13U) ^ (W[ 2].z>>10U)) + W[ 1].y + (rotate(W[ 3].y,25U) ^ rotate(W[ 3].y,14U) ^ (W[ 3].y>>3U));
  S0.w += (rotate(S0.x,26U) ^ rotate(S0.x,21U) ^ rotate(S0.x,7U)); S0.w += bitselect(S0.z,S0.y,S0.x); S0.w += W[3].x+ K[59]; S1.w += S0.w; S0.w += (rotate(S1.x,30U) ^ rotate(S1.x,19U) ^ rotate(S1.x,10U)); S0.w += bitselect(S1.z,S1.y,(S1.x^S1.z));;

  W[ 3].y += (rotate(W[ 2].w,15U) ^ rotate(W[ 2].w,13U) ^ (W[ 2].w>>10U)) + W[ 1].z + (rotate(W[ 3].z,25U) ^ rotate(W[ 3].z,14U) ^ (W[ 3].z>>3U));
  S0.z += (rotate(S1.w,26U) ^ rotate(S1.w,21U) ^ rotate(S1.w,7U)); S0.z += bitselect(S0.y,S0.x,S1.w); S0.z += W[3].y+ K[60]; S1.z += S0.z; S0.z += (rotate(S0.w,30U) ^ rotate(S0.w,19U) ^ rotate(S0.w,10U)); S0.z += bitselect(S1.y,S1.x,(S0.w^S1.y));;

  W[ 3].z += (rotate(W[ 3].x,15U) ^ rotate(W[ 3].x,13U) ^ (W[ 3].x>>10U)) + W[ 1].w + (rotate(W[ 3].w,25U) ^ rotate(W[ 3].w,14U) ^ (W[ 3].w>>3U));
  S0.y += (rotate(S1.z,26U) ^ rotate(S1.z,21U) ^ rotate(S1.z,7U)); S0.y += bitselect(S0.x,S1.w,S1.z); S0.y += W[3].z+ K[61]; S1.y += S0.y; S0.y += (rotate(S0.z,30U) ^ rotate(S0.z,19U) ^ rotate(S0.z,10U)); S0.y += bitselect(S1.x,S0.w,(S0.z^S1.x));;

  W[ 3].w += (rotate(W[ 3].y,15U) ^ rotate(W[ 3].y,13U) ^ (W[ 3].y>>10U)) + W[ 2].x + (rotate(W[ 0].x,25U) ^ rotate(W[ 0].x,14U) ^ (W[ 0].x>>3U));
  S0.x += (rotate(S1.y,26U) ^ rotate(S1.y,21U) ^ rotate(S1.y,7U)); S0.x += bitselect(S1.w,S1.z,S1.y); S0.x += W[3].w+ K[62]; S1.x += S0.x; S0.x += (rotate(S0.y,30U) ^ rotate(S0.y,19U) ^ rotate(S0.y,10U)); S0.x += bitselect(S0.w,S0.z,(S0.y^S0.w));;
# 435 "/usr/local/share/xpmminer/sha256.h"
  *state0 += S0;
  *state1 += S1;
}

void SHA256_fresh(uint4*restrict state0,uint4*restrict state1, const uint4 block0, const uint4 block1, const uint4 block2, const uint4 block3)
{
# 450 "/usr/local/share/xpmminer/sha256.h"
  uint4 W[4];

  W[0].x = block0.x;
  (*state0).w= K[63] +W[0].x;
  (*state1).w= K[64] +W[0].x;

  W[0].y = block0.y;
  (*state0).z= K[65] +(rotate((*state0).w,26U) ^ rotate((*state0).w,21U) ^ rotate((*state0).w,7U))+bitselect(K[67],K[66],(*state0).w)+W[0].y;
  (*state1).z= K[68] +(*state0).z+(rotate((*state1).w,30U) ^ rotate((*state1).w,19U) ^ rotate((*state1).w,10U))+bitselect(K[70],K[69],(*state1).w);

  W[0].z = block0.z;
  (*state0).y= K[71] +(rotate((*state0).z,26U) ^ rotate((*state0).z,21U) ^ rotate((*state0).z,7U))+bitselect(K[66],(*state0).w,(*state0).z)+W[0].z;
  (*state1).y= K[72] +(*state0).y+(rotate((*state1).z,30U) ^ rotate((*state1).z,19U) ^ rotate((*state1).z,10U))+bitselect(K[73],(*state1).w,((*state1).z^K[73]));

  W[0].w = block0.w;
  (*state0).x= K[74] +(rotate((*state0).y,26U) ^ rotate((*state0).y,21U) ^ rotate((*state0).y,7U))+bitselect((*state0).w,(*state0).z,(*state0).y)+W[0].w;
  (*state1).x= K[75] +(*state0).x+(rotate((*state1).y,30U) ^ rotate((*state1).y,19U) ^ rotate((*state1).y,10U))+bitselect((*state1).w,(*state1).z,((*state1).y^(*state1).w));

  W[1].x = block1.x;
  (*state0).w += (rotate((*state0).x,26U) ^ rotate((*state0).x,21U) ^ rotate((*state0).x,7U)); (*state0).w += bitselect((*state0).z,(*state0).y,(*state0).x); (*state0).w += W[1].x+ K[4]; (*state1).w += (*state0).w; (*state0).w += (rotate((*state1).x,30U) ^ rotate((*state1).x,19U) ^ rotate((*state1).x,10U)); (*state0).w += bitselect((*state1).z,(*state1).y,((*state1).x^(*state1).z));;
  W[1].y = block1.y;
  (*state0).z += (rotate((*state1).w,26U) ^ rotate((*state1).w,21U) ^ rotate((*state1).w,7U)); (*state0).z += bitselect((*state0).y,(*state0).x,(*state1).w); (*state0).z += W[1].y+ K[5]; (*state1).z += (*state0).z; (*state0).z += (rotate((*state0).w,30U) ^ rotate((*state0).w,19U) ^ rotate((*state0).w,10U)); (*state0).z += bitselect((*state1).y,(*state1).x,((*state0).w^(*state1).y));;
  W[1].z = block1.z;
  (*state0).y += (rotate((*state1).z,26U) ^ rotate((*state1).z,21U) ^ rotate((*state1).z,7U)); (*state0).y += bitselect((*state0).x,(*state1).w,(*state1).z); (*state0).y += W[1].z+ K[6]; (*state1).y += (*state0).y; (*state0).y += (rotate((*state0).z,30U) ^ rotate((*state0).z,19U) ^ rotate((*state0).z,10U)); (*state0).y += bitselect((*state1).x,(*state0).w,((*state0).z^(*state1).x));;
  W[1].w = block1.w;
  (*state0).x += (rotate((*state1).y,26U) ^ rotate((*state1).y,21U) ^ rotate((*state1).y,7U)); (*state0).x += bitselect((*state1).w,(*state1).z,(*state1).y); (*state0).x += W[1].w+ K[7]; (*state1).x += (*state0).x; (*state0).x += (rotate((*state0).y,30U) ^ rotate((*state0).y,19U) ^ rotate((*state0).y,10U)); (*state0).x += bitselect((*state0).w,(*state0).z,((*state0).y^(*state0).w));;

  W[2].x = block2.x;
  (*state1).w += (rotate((*state1).x,26U) ^ rotate((*state1).x,21U) ^ rotate((*state1).x,7U)); (*state1).w += bitselect((*state1).z,(*state1).y,(*state1).x); (*state1).w += W[2].x+ K[8]; (*state0).w += (*state1).w; (*state1).w += (rotate((*state0).x,30U) ^ rotate((*state0).x,19U) ^ rotate((*state0).x,10U)); (*state1).w += bitselect((*state0).z,(*state0).y,((*state0).x^(*state0).z));;
  W[2].y = block2.y;
  (*state1).z += (rotate((*state0).w,26U) ^ rotate((*state0).w,21U) ^ rotate((*state0).w,7U)); (*state1).z += bitselect((*state1).y,(*state1).x,(*state0).w); (*state1).z += W[2].y+ K[9]; (*state0).z += (*state1).z; (*state1).z += (rotate((*state1).w,30U) ^ rotate((*state1).w,19U) ^ rotate((*state1).w,10U)); (*state1).z += bitselect((*state0).y,(*state0).x,((*state1).w^(*state0).y));;
  W[2].z = block2.z;
  (*state1).y += (rotate((*state0).z,26U) ^ rotate((*state0).z,21U) ^ rotate((*state0).z,7U)); (*state1).y += bitselect((*state1).x,(*state0).w,(*state0).z); (*state1).y += W[2].z+ K[10]; (*state0).y += (*state1).y; (*state1).y += (rotate((*state1).z,30U) ^ rotate((*state1).z,19U) ^ rotate((*state1).z,10U)); (*state1).y += bitselect((*state0).x,(*state1).w,((*state1).z^(*state0).x));;
  W[2].w = block2.w;
  (*state1).x += (rotate((*state0).y,26U) ^ rotate((*state0).y,21U) ^ rotate((*state0).y,7U)); (*state1).x += bitselect((*state0).w,(*state0).z,(*state0).y); (*state1).x += W[2].w+ K[11]; (*state0).x += (*state1).x; (*state1).x += (rotate((*state1).y,30U) ^ rotate((*state1).y,19U) ^ rotate((*state1).y,10U)); (*state1).x += bitselect((*state1).w,(*state1).z,((*state1).y^(*state1).w));;

  W[3].x = block3.x;
  (*state0).w += (rotate((*state0).x,26U) ^ rotate((*state0).x,21U) ^ rotate((*state0).x,7U)); (*state0).w += bitselect((*state0).z,(*state0).y,(*state0).x); (*state0).w += W[3].x+ K[12]; (*state1).w += (*state0).w; (*state0).w += (rotate((*state1).x,30U) ^ rotate((*state1).x,19U) ^ rotate((*state1).x,10U)); (*state0).w += bitselect((*state1).z,(*state1).y,((*state1).x^(*state1).z));;
  W[3].y = block3.y;
  (*state0).z += (rotate((*state1).w,26U) ^ rotate((*state1).w,21U) ^ rotate((*state1).w,7U)); (*state0).z += bitselect((*state0).y,(*state0).x,(*state1).w); (*state0).z += W[3].y+ K[13]; (*state1).z += (*state0).z; (*state0).z += (rotate((*state0).w,30U) ^ rotate((*state0).w,19U) ^ rotate((*state0).w,10U)); (*state0).z += bitselect((*state1).y,(*state1).x,((*state0).w^(*state1).y));;
  W[3].z = block3.z;
  (*state0).y += (rotate((*state1).z,26U) ^ rotate((*state1).z,21U) ^ rotate((*state1).z,7U)); (*state0).y += bitselect((*state0).x,(*state1).w,(*state1).z); (*state0).y += W[3].z+ K[14]; (*state1).y += (*state0).y; (*state0).y += (rotate((*state0).z,30U) ^ rotate((*state0).z,19U) ^ rotate((*state0).z,10U)); (*state0).y += bitselect((*state1).x,(*state0).w,((*state0).z^(*state1).x));;
  W[3].w = block3.w;
  (*state0).x += (rotate((*state1).y,26U) ^ rotate((*state1).y,21U) ^ rotate((*state1).y,7U)); (*state0).x += bitselect((*state1).w,(*state1).z,(*state1).y); (*state0).x += W[3].w+ K[76]; (*state1).x += (*state0).x; (*state0).x += (rotate((*state0).y,30U) ^ rotate((*state0).y,19U) ^ rotate((*state0).y,10U)); (*state0).x += bitselect((*state0).w,(*state0).z,((*state0).y^(*state0).w));;

  W[0].x += (rotate(W[3].z,15U) ^ rotate(W[3].z,13U) ^ (W[3].z>>10U)) + W[2].y + (rotate(W[0].y,25U) ^ rotate(W[0].y,14U) ^ (W[0].y>>3U));
  (*state1).w += (rotate((*state1).x,26U) ^ rotate((*state1).x,21U) ^ rotate((*state1).x,7U)); (*state1).w += bitselect((*state1).z,(*state1).y,(*state1).x); (*state1).w += W[0].x+ K[15]; (*state0).w += (*state1).w; (*state1).w += (rotate((*state0).x,30U) ^ rotate((*state0).x,19U) ^ rotate((*state0).x,10U)); (*state1).w += bitselect((*state0).z,(*state0).y,((*state0).x^(*state0).z));;

  W[0].y += (rotate(W[3].w,15U) ^ rotate(W[3].w,13U) ^ (W[3].w>>10U)) + W[2].z + (rotate(W[0].z,25U) ^ rotate(W[0].z,14U) ^ (W[0].z>>3U));
  (*state1).z += (rotate((*state0).w,26U) ^ rotate((*state0).w,21U) ^ rotate((*state0).w,7U)); (*state1).z += bitselect((*state1).y,(*state1).x,(*state0).w); (*state1).z += W[0].y+ K[16]; (*state0).z += (*state1).z; (*state1).z += (rotate((*state1).w,30U) ^ rotate((*state1).w,19U) ^ rotate((*state1).w,10U)); (*state1).z += bitselect((*state0).y,(*state0).x,((*state1).w^(*state0).y));;

  W[0].z += (rotate(W[0].x,15U) ^ rotate(W[0].x,13U) ^ (W[0].x>>10U)) + W[2].w + (rotate(W[0].w,25U) ^ rotate(W[0].w,14U) ^ (W[0].w>>3U));
  (*state1).y += (rotate((*state0).z,26U) ^ rotate((*state0).z,21U) ^ rotate((*state0).z,7U)); (*state1).y += bitselect((*state1).x,(*state0).w,(*state0).z); (*state1).y += W[0].z+ K[17]; (*state0).y += (*state1).y; (*state1).y += (rotate((*state1).z,30U) ^ rotate((*state1).z,19U) ^ rotate((*state1).z,10U)); (*state1).y += bitselect((*state0).x,(*state1).w,((*state1).z^(*state0).x));;

  W[0].w += (rotate(W[0].y,15U) ^ rotate(W[0].y,13U) ^ (W[0].y>>10U)) + W[3].x + (rotate(W[1].x,25U) ^ rotate(W[1].x,14U) ^ (W[1].x>>3U));
  (*state1).x += (rotate((*state0).y,26U) ^ rotate((*state0).y,21U) ^ rotate((*state0).y,7U)); (*state1).x += bitselect((*state0).w,(*state0).z,(*state0).y); (*state1).x += W[0].w+ K[18]; (*state0).x += (*state1).x; (*state1).x += (rotate((*state1).y,30U) ^ rotate((*state1).y,19U) ^ rotate((*state1).y,10U)); (*state1).x += bitselect((*state1).w,(*state1).z,((*state1).y^(*state1).w));;

  W[1].x += (rotate(W[0].z,15U) ^ rotate(W[0].z,13U) ^ (W[0].z>>10U)) + W[3].y + (rotate(W[1].y,25U) ^ rotate(W[1].y,14U) ^ (W[1].y>>3U));
  (*state0).w += (rotate((*state0).x,26U) ^ rotate((*state0).x,21U) ^ rotate((*state0).x,7U)); (*state0).w += bitselect((*state0).z,(*state0).y,(*state0).x); (*state0).w += W[1].x+ K[19]; (*state1).w += (*state0).w; (*state0).w += (rotate((*state1).x,30U) ^ rotate((*state1).x,19U) ^ rotate((*state1).x,10U)); (*state0).w += bitselect((*state1).z,(*state1).y,((*state1).x^(*state1).z));;

  W[1].y += (rotate(W[0].w,15U) ^ rotate(W[0].w,13U) ^ (W[0].w>>10U)) + W[3].z + (rotate(W[1].z,25U) ^ rotate(W[1].z,14U) ^ (W[1].z>>3U));
  (*state0).z += (rotate((*state1).w,26U) ^ rotate((*state1).w,21U) ^ rotate((*state1).w,7U)); (*state0).z += bitselect((*state0).y,(*state0).x,(*state1).w); (*state0).z += W[1].y+ K[20]; (*state1).z += (*state0).z; (*state0).z += (rotate((*state0).w,30U) ^ rotate((*state0).w,19U) ^ rotate((*state0).w,10U)); (*state0).z += bitselect((*state1).y,(*state1).x,((*state0).w^(*state1).y));;

  W[1].z += (rotate(W[1].x,15U) ^ rotate(W[1].x,13U) ^ (W[1].x>>10U)) + W[3].w + (rotate(W[1].w,25U) ^ rotate(W[1].w,14U) ^ (W[1].w>>3U));
  (*state0).y += (rotate((*state1).z,26U) ^ rotate((*state1).z,21U) ^ rotate((*state1).z,7U)); (*state0).y += bitselect((*state0).x,(*state1).w,(*state1).z); (*state0).y += W[1].z+ K[21]; (*state1).y += (*state0).y; (*state0).y += (rotate((*state0).z,30U) ^ rotate((*state0).z,19U) ^ rotate((*state0).z,10U)); (*state0).y += bitselect((*state1).x,(*state0).w,((*state0).z^(*state1).x));;

  W[1].w += (rotate(W[1].y,15U) ^ rotate(W[1].y,13U) ^ (W[1].y>>10U)) + W[0].x + (rotate(W[2].x,25U) ^ rotate(W[2].x,14U) ^ (W[2].x>>3U));
  (*state0).x += (rotate((*state1).y,26U) ^ rotate((*state1).y,21U) ^ rotate((*state1).y,7U)); (*state0).x += bitselect((*state1).w,(*state1).z,(*state1).y); (*state0).x += W[1].w+ K[22]; (*state1).x += (*state0).x; (*state0).x += (rotate((*state0).y,30U) ^ rotate((*state0).y,19U) ^ rotate((*state0).y,10U)); (*state0).x += bitselect((*state0).w,(*state0).z,((*state0).y^(*state0).w));;

  W[2].x += (rotate(W[1].z,15U) ^ rotate(W[1].z,13U) ^ (W[1].z>>10U)) + W[0].y + (rotate(W[2].y,25U) ^ rotate(W[2].y,14U) ^ (W[2].y>>3U));
  (*state1).w += (rotate((*state1).x,26U) ^ rotate((*state1).x,21U) ^ rotate((*state1).x,7U)); (*state1).w += bitselect((*state1).z,(*state1).y,(*state1).x); (*state1).w += W[2].x+ K[23]; (*state0).w += (*state1).w; (*state1).w += (rotate((*state0).x,30U) ^ rotate((*state0).x,19U) ^ rotate((*state0).x,10U)); (*state1).w += bitselect((*state0).z,(*state0).y,((*state0).x^(*state0).z));;

  W[2].y += (rotate(W[1].w,15U) ^ rotate(W[1].w,13U) ^ (W[1].w>>10U)) + W[0].z + (rotate(W[2].z,25U) ^ rotate(W[2].z,14U) ^ (W[2].z>>3U));
  (*state1).z += (rotate((*state0).w,26U) ^ rotate((*state0).w,21U) ^ rotate((*state0).w,7U)); (*state1).z += bitselect((*state1).y,(*state1).x,(*state0).w); (*state1).z += W[2].y+ K[24]; (*state0).z += (*state1).z; (*state1).z += (rotate((*state1).w,30U) ^ rotate((*state1).w,19U) ^ rotate((*state1).w,10U)); (*state1).z += bitselect((*state0).y,(*state0).x,((*state1).w^(*state0).y));;

  W[2].z += (rotate(W[2].x,15U) ^ rotate(W[2].x,13U) ^ (W[2].x>>10U)) + W[0].w + (rotate(W[2].w,25U) ^ rotate(W[2].w,14U) ^ (W[2].w>>3U));
  (*state1).y += (rotate((*state0).z,26U) ^ rotate((*state0).z,21U) ^ rotate((*state0).z,7U)); (*state1).y += bitselect((*state1).x,(*state0).w,(*state0).z); (*state1).y += W[2].z+ K[25]; (*state0).y += (*state1).y; (*state1).y += (rotate((*state1).z,30U) ^ rotate((*state1).z,19U) ^ rotate((*state1).z,10U)); (*state1).y += bitselect((*state0).x,(*state1).w,((*state1).z^(*state0).x));;

  W[2].w += (rotate(W[2].y,15U) ^ rotate(W[2].y,13U) ^ (W[2].y>>10U)) + W[1].x + (rotate(W[3].x,25U) ^ rotate(W[3].x,14U) ^ (W[3].x>>3U));
  (*state1).x += (rotate((*state0).y,26U) ^ rotate((*state0).y,21U) ^ rotate((*state0).y,7U)); (*state1).x += bitselect((*state0).w,(*state0).z,(*state0).y); (*state1).x += W[2].w+ K[26]; (*state0).x += (*state1).x; (*state1).x += (rotate((*state1).y,30U) ^ rotate((*state1).y,19U) ^ rotate((*state1).y,10U)); (*state1).x += bitselect((*state1).w,(*state1).z,((*state1).y^(*state1).w));;

  W[3].x += (rotate(W[2].z,15U) ^ rotate(W[2].z,13U) ^ (W[2].z>>10U)) + W[1].y + (rotate(W[3].y,25U) ^ rotate(W[3].y,14U) ^ (W[3].y>>3U));
  (*state0).w += (rotate((*state0).x,26U) ^ rotate((*state0).x,21U) ^ rotate((*state0).x,7U)); (*state0).w += bitselect((*state0).z,(*state0).y,(*state0).x); (*state0).w += W[3].x+ K[27]; (*state1).w += (*state0).w; (*state0).w += (rotate((*state1).x,30U) ^ rotate((*state1).x,19U) ^ rotate((*state1).x,10U)); (*state0).w += bitselect((*state1).z,(*state1).y,((*state1).x^(*state1).z));;

  W[3].y += (rotate(W[2].w,15U) ^ rotate(W[2].w,13U) ^ (W[2].w>>10U)) + W[1].z + (rotate(W[3].z,25U) ^ rotate(W[3].z,14U) ^ (W[3].z>>3U));
  (*state0).z += (rotate((*state1).w,26U) ^ rotate((*state1).w,21U) ^ rotate((*state1).w,7U)); (*state0).z += bitselect((*state0).y,(*state0).x,(*state1).w); (*state0).z += W[3].y+ K[28]; (*state1).z += (*state0).z; (*state0).z += (rotate((*state0).w,30U) ^ rotate((*state0).w,19U) ^ rotate((*state0).w,10U)); (*state0).z += bitselect((*state1).y,(*state1).x,((*state0).w^(*state1).y));;

  W[3].z += (rotate(W[3].x,15U) ^ rotate(W[3].x,13U) ^ (W[3].x>>10U)) + W[1].w + (rotate(W[3].w,25U) ^ rotate(W[3].w,14U) ^ (W[3].w>>3U));
  (*state0).y += (rotate((*state1).z,26U) ^ rotate((*state1).z,21U) ^ rotate((*state1).z,7U)); (*state0).y += bitselect((*state0).x,(*state1).w,(*state1).z); (*state0).y += W[3].z+ K[29]; (*state1).y += (*state0).y; (*state0).y += (rotate((*state0).z,30U) ^ rotate((*state0).z,19U) ^ rotate((*state0).z,10U)); (*state0).y += bitselect((*state1).x,(*state0).w,((*state0).z^(*state1).x));;

  W[3].w += (rotate(W[3].y,15U) ^ rotate(W[3].y,13U) ^ (W[3].y>>10U)) + W[2].x + (rotate(W[0].x,25U) ^ rotate(W[0].x,14U) ^ (W[0].x>>3U));
  (*state0).x += (rotate((*state1).y,26U) ^ rotate((*state1).y,21U) ^ rotate((*state1).y,7U)); (*state0).x += bitselect((*state1).w,(*state1).z,(*state1).y); (*state0).x += W[3].w+ K[30]; (*state1).x += (*state0).x; (*state0).x += (rotate((*state0).y,30U) ^ rotate((*state0).y,19U) ^ rotate((*state0).y,10U)); (*state0).x += bitselect((*state0).w,(*state0).z,((*state0).y^(*state0).w));;

  W[0].x += (rotate(W[3].z,15U) ^ rotate(W[3].z,13U) ^ (W[3].z>>10U)) + W[2].y + (rotate(W[0].y,25U) ^ rotate(W[0].y,14U) ^ (W[0].y>>3U));
  (*state1).w += (rotate((*state1).x,26U) ^ rotate((*state1).x,21U) ^ rotate((*state1).x,7U)); (*state1).w += bitselect((*state1).z,(*state1).y,(*state1).x); (*state1).w += W[0].x+ K[31]; (*state0).w += (*state1).w; (*state1).w += (rotate((*state0).x,30U) ^ rotate((*state0).x,19U) ^ rotate((*state0).x,10U)); (*state1).w += bitselect((*state0).z,(*state0).y,((*state0).x^(*state0).z));;

  W[0].y += (rotate(W[3].w,15U) ^ rotate(W[3].w,13U) ^ (W[3].w>>10U)) + W[2].z + (rotate(W[0].z,25U) ^ rotate(W[0].z,14U) ^ (W[0].z>>3U));
  (*state1).z += (rotate((*state0).w,26U) ^ rotate((*state0).w,21U) ^ rotate((*state0).w,7U)); (*state1).z += bitselect((*state1).y,(*state1).x,(*state0).w); (*state1).z += W[0].y+ K[32]; (*state0).z += (*state1).z; (*state1).z += (rotate((*state1).w,30U) ^ rotate((*state1).w,19U) ^ rotate((*state1).w,10U)); (*state1).z += bitselect((*state0).y,(*state0).x,((*state1).w^(*state0).y));;

  W[0].z += (rotate(W[0].x,15U) ^ rotate(W[0].x,13U) ^ (W[0].x>>10U)) + W[2].w + (rotate(W[0].w,25U) ^ rotate(W[0].w,14U) ^ (W[0].w>>3U));
  (*state1).y += (rotate((*state0).z,26U) ^ rotate((*state0).z,21U) ^ rotate((*state0).z,7U)); (*state1).y += bitselect((*state1).x,(*state0).w,(*state0).z); (*state1).y += W[0].z+ K[33]; (*state0).y += (*state1).y; (*state1).y += (rotate((*state1).z,30U) ^ rotate((*state1).z,19U) ^ rotate((*state1).z,10U)); (*state1).y += bitselect((*state0).x,(*state1).w,((*state1).z^(*state0).x));;

  W[0].w += (rotate(W[0].y,15U) ^ rotate(W[0].y,13U) ^ (W[0].y>>10U)) + W[3].x + (rotate(W[1].x,25U) ^ rotate(W[1].x,14U) ^ (W[1].x>>3U));
  (*state1).x += (rotate((*state0).y,26U) ^ rotate((*state0).y,21U) ^ rotate((*state0).y,7U)); (*state1).x += bitselect((*state0).w,(*state0).z,(*state0).y); (*state1).x += W[0].w+ K[34]; (*state0).x += (*state1).x; (*state1).x += (rotate((*state1).y,30U) ^ rotate((*state1).y,19U) ^ rotate((*state1).y,10U)); (*state1).x += bitselect((*state1).w,(*state1).z,((*state1).y^(*state1).w));;

  W[1].x += (rotate(W[0].z,15U) ^ rotate(W[0].z,13U) ^ (W[0].z>>10U)) + W[3].y + (rotate(W[1].y,25U) ^ rotate(W[1].y,14U) ^ (W[1].y>>3U));
  (*state0).w += (rotate((*state0).x,26U) ^ rotate((*state0).x,21U) ^ rotate((*state0).x,7U)); (*state0).w += bitselect((*state0).z,(*state0).y,(*state0).x); (*state0).w += W[1].x+ K[35]; (*state1).w += (*state0).w; (*state0).w += (rotate((*state1).x,30U) ^ rotate((*state1).x,19U) ^ rotate((*state1).x,10U)); (*state0).w += bitselect((*state1).z,(*state1).y,((*state1).x^(*state1).z));;

  W[1].y += (rotate(W[0].w,15U) ^ rotate(W[0].w,13U) ^ (W[0].w>>10U)) + W[3].z + (rotate(W[1].z,25U) ^ rotate(W[1].z,14U) ^ (W[1].z>>3U));
  (*state0).z += (rotate((*state1).w,26U) ^ rotate((*state1).w,21U) ^ rotate((*state1).w,7U)); (*state0).z += bitselect((*state0).y,(*state0).x,(*state1).w); (*state0).z += W[1].y+ K[36]; (*state1).z += (*state0).z; (*state0).z += (rotate((*state0).w,30U) ^ rotate((*state0).w,19U) ^ rotate((*state0).w,10U)); (*state0).z += bitselect((*state1).y,(*state1).x,((*state0).w^(*state1).y));;

  W[1].z += (rotate(W[1].x,15U) ^ rotate(W[1].x,13U) ^ (W[1].x>>10U)) + W[3].w + (rotate(W[1].w,25U) ^ rotate(W[1].w,14U) ^ (W[1].w>>3U));
  (*state0).y += (rotate((*state1).z,26U) ^ rotate((*state1).z,21U) ^ rotate((*state1).z,7U)); (*state0).y += bitselect((*state0).x,(*state1).w,(*state1).z); (*state0).y += W[1].z+ K[37]; (*state1).y += (*state0).y; (*state0).y += (rotate((*state0).z,30U) ^ rotate((*state0).z,19U) ^ rotate((*state0).z,10U)); (*state0).y += bitselect((*state1).x,(*state0).w,((*state0).z^(*state1).x));;

  W[1].w += (rotate(W[1].y,15U) ^ rotate(W[1].y,13U) ^ (W[1].y>>10U)) + W[0].x + (rotate(W[2].x,25U) ^ rotate(W[2].x,14U) ^ (W[2].x>>3U));
  (*state0).x += (rotate((*state1).y,26U) ^ rotate((*state1).y,21U) ^ rotate((*state1).y,7U)); (*state0).x += bitselect((*state1).w,(*state1).z,(*state1).y); (*state0).x += W[1].w+ K[38]; (*state1).x += (*state0).x; (*state0).x += (rotate((*state0).y,30U) ^ rotate((*state0).y,19U) ^ rotate((*state0).y,10U)); (*state0).x += bitselect((*state0).w,(*state0).z,((*state0).y^(*state0).w));;

  W[2].x += (rotate(W[1].z,15U) ^ rotate(W[1].z,13U) ^ (W[1].z>>10U)) + W[0].y + (rotate(W[2].y,25U) ^ rotate(W[2].y,14U) ^ (W[2].y>>3U));
  (*state1).w += (rotate((*state1).x,26U) ^ rotate((*state1).x,21U) ^ rotate((*state1).x,7U)); (*state1).w += bitselect((*state1).z,(*state1).y,(*state1).x); (*state1).w += W[2].x+ K[39]; (*state0).w += (*state1).w; (*state1).w += (rotate((*state0).x,30U) ^ rotate((*state0).x,19U) ^ rotate((*state0).x,10U)); (*state1).w += bitselect((*state0).z,(*state0).y,((*state0).x^(*state0).z));;

  W[2].y += (rotate(W[1].w,15U) ^ rotate(W[1].w,13U) ^ (W[1].w>>10U)) + W[0].z + (rotate(W[2].z,25U) ^ rotate(W[2].z,14U) ^ (W[2].z>>3U));
  (*state1).z += (rotate((*state0).w,26U) ^ rotate((*state0).w,21U) ^ rotate((*state0).w,7U)); (*state1).z += bitselect((*state1).y,(*state1).x,(*state0).w); (*state1).z += W[2].y+ K[40]; (*state0).z += (*state1).z; (*state1).z += (rotate((*state1).w,30U) ^ rotate((*state1).w,19U) ^ rotate((*state1).w,10U)); (*state1).z += bitselect((*state0).y,(*state0).x,((*state1).w^(*state0).y));;

  W[2].z += (rotate(W[2].x,15U) ^ rotate(W[2].x,13U) ^ (W[2].x>>10U)) + W[0].w + (rotate(W[2].w,25U) ^ rotate(W[2].w,14U) ^ (W[2].w>>3U));
  (*state1).y += (rotate((*state0).z,26U) ^ rotate((*state0).z,21U) ^ rotate((*state0).z,7U)); (*state1).y += bitselect((*state1).x,(*state0).w,(*state0).z); (*state1).y += W[2].z+ K[41]; (*state0).y += (*state1).y; (*state1).y += (rotate((*state1).z,30U) ^ rotate((*state1).z,19U) ^ rotate((*state1).z,10U)); (*state1).y += bitselect((*state0).x,(*state1).w,((*state1).z^(*state0).x));;

  W[2].w += (rotate(W[2].y,15U) ^ rotate(W[2].y,13U) ^ (W[2].y>>10U)) + W[1].x + (rotate(W[3].x,25U) ^ rotate(W[3].x,14U) ^ (W[3].x>>3U));
  (*state1).x += (rotate((*state0).y,26U) ^ rotate((*state0).y,21U) ^ rotate((*state0).y,7U)); (*state1).x += bitselect((*state0).w,(*state0).z,(*state0).y); (*state1).x += W[2].w+ K[42]; (*state0).x += (*state1).x; (*state1).x += (rotate((*state1).y,30U) ^ rotate((*state1).y,19U) ^ rotate((*state1).y,10U)); (*state1).x += bitselect((*state1).w,(*state1).z,((*state1).y^(*state1).w));;

  W[3].x += (rotate(W[2].z,15U) ^ rotate(W[2].z,13U) ^ (W[2].z>>10U)) + W[1].y + (rotate(W[3].y,25U) ^ rotate(W[3].y,14U) ^ (W[3].y>>3U));
  (*state0).w += (rotate((*state0).x,26U) ^ rotate((*state0).x,21U) ^ rotate((*state0).x,7U)); (*state0).w += bitselect((*state0).z,(*state0).y,(*state0).x); (*state0).w += W[3].x+ K[43]; (*state1).w += (*state0).w; (*state0).w += (rotate((*state1).x,30U) ^ rotate((*state1).x,19U) ^ rotate((*state1).x,10U)); (*state0).w += bitselect((*state1).z,(*state1).y,((*state1).x^(*state1).z));;

  W[3].y += (rotate(W[2].w,15U) ^ rotate(W[2].w,13U) ^ (W[2].w>>10U)) + W[1].z + (rotate(W[3].z,25U) ^ rotate(W[3].z,14U) ^ (W[3].z>>3U));
  (*state0).z += (rotate((*state1).w,26U) ^ rotate((*state1).w,21U) ^ rotate((*state1).w,7U)); (*state0).z += bitselect((*state0).y,(*state0).x,(*state1).w); (*state0).z += W[3].y+ K[44]; (*state1).z += (*state0).z; (*state0).z += (rotate((*state0).w,30U) ^ rotate((*state0).w,19U) ^ rotate((*state0).w,10U)); (*state0).z += bitselect((*state1).y,(*state1).x,((*state0).w^(*state1).y));;

  W[3].z += (rotate(W[3].x,15U) ^ rotate(W[3].x,13U) ^ (W[3].x>>10U)) + W[1].w + (rotate(W[3].w,25U) ^ rotate(W[3].w,14U) ^ (W[3].w>>3U));
  (*state0).y += (rotate((*state1).z,26U) ^ rotate((*state1).z,21U) ^ rotate((*state1).z,7U)); (*state0).y += bitselect((*state0).x,(*state1).w,(*state1).z); (*state0).y += W[3].z+ K[45]; (*state1).y += (*state0).y; (*state0).y += (rotate((*state0).z,30U) ^ rotate((*state0).z,19U) ^ rotate((*state0).z,10U)); (*state0).y += bitselect((*state1).x,(*state0).w,((*state0).z^(*state1).x));;

  W[3].w += (rotate(W[3].y,15U) ^ rotate(W[3].y,13U) ^ (W[3].y>>10U)) + W[2].x + (rotate(W[0].x,25U) ^ rotate(W[0].x,14U) ^ (W[0].x>>3U));
  (*state0).x += (rotate((*state1).y,26U) ^ rotate((*state1).y,21U) ^ rotate((*state1).y,7U)); (*state0).x += bitselect((*state1).w,(*state1).z,(*state1).y); (*state0).x += W[3].w+ K[46]; (*state1).x += (*state0).x; (*state0).x += (rotate((*state0).y,30U) ^ rotate((*state0).y,19U) ^ rotate((*state0).y,10U)); (*state0).x += bitselect((*state0).w,(*state0).z,((*state0).y^(*state0).w));;

  W[0].x += (rotate(W[3].z,15U) ^ rotate(W[3].z,13U) ^ (W[3].z>>10U)) + W[2].y + (rotate(W[0].y,25U) ^ rotate(W[0].y,14U) ^ (W[0].y>>3U));
  (*state1).w += (rotate((*state1).x,26U) ^ rotate((*state1).x,21U) ^ rotate((*state1).x,7U)); (*state1).w += bitselect((*state1).z,(*state1).y,(*state1).x); (*state1).w += W[0].x+ K[47]; (*state0).w += (*state1).w; (*state1).w += (rotate((*state0).x,30U) ^ rotate((*state0).x,19U) ^ rotate((*state0).x,10U)); (*state1).w += bitselect((*state0).z,(*state0).y,((*state0).x^(*state0).z));;

  W[0].y += (rotate(W[3].w,15U) ^ rotate(W[3].w,13U) ^ (W[3].w>>10U)) + W[2].z + (rotate(W[0].z,25U) ^ rotate(W[0].z,14U) ^ (W[0].z>>3U));
  (*state1).z += (rotate((*state0).w,26U) ^ rotate((*state0).w,21U) ^ rotate((*state0).w,7U)); (*state1).z += bitselect((*state1).y,(*state1).x,(*state0).w); (*state1).z += W[0].y+ K[48]; (*state0).z += (*state1).z; (*state1).z += (rotate((*state1).w,30U) ^ rotate((*state1).w,19U) ^ rotate((*state1).w,10U)); (*state1).z += bitselect((*state0).y,(*state0).x,((*state1).w^(*state0).y));;

  W[0].z += (rotate(W[0].x,15U) ^ rotate(W[0].x,13U) ^ (W[0].x>>10U)) + W[2].w + (rotate(W[0].w,25U) ^ rotate(W[0].w,14U) ^ (W[0].w>>3U));
  (*state1).y += (rotate((*state0).z,26U) ^ rotate((*state0).z,21U) ^ rotate((*state0).z,7U)); (*state1).y += bitselect((*state1).x,(*state0).w,(*state0).z); (*state1).y += W[0].z+ K[49]; (*state0).y += (*state1).y; (*state1).y += (rotate((*state1).z,30U) ^ rotate((*state1).z,19U) ^ rotate((*state1).z,10U)); (*state1).y += bitselect((*state0).x,(*state1).w,((*state1).z^(*state0).x));;

  W[0].w += (rotate(W[0].y,15U) ^ rotate(W[0].y,13U) ^ (W[0].y>>10U)) + W[3].x + (rotate(W[1].x,25U) ^ rotate(W[1].x,14U) ^ (W[1].x>>3U));
  (*state1).x += (rotate((*state0).y,26U) ^ rotate((*state0).y,21U) ^ rotate((*state0).y,7U)); (*state1).x += bitselect((*state0).w,(*state0).z,(*state0).y); (*state1).x += W[0].w+ K[50]; (*state0).x += (*state1).x; (*state1).x += (rotate((*state1).y,30U) ^ rotate((*state1).y,19U) ^ rotate((*state1).y,10U)); (*state1).x += bitselect((*state1).w,(*state1).z,((*state1).y^(*state1).w));;

  W[1].x += (rotate(W[0].z,15U) ^ rotate(W[0].z,13U) ^ (W[0].z>>10U)) + W[3].y + (rotate(W[1].y,25U) ^ rotate(W[1].y,14U) ^ (W[1].y>>3U));
  (*state0).w += (rotate((*state0).x,26U) ^ rotate((*state0).x,21U) ^ rotate((*state0).x,7U)); (*state0).w += bitselect((*state0).z,(*state0).y,(*state0).x); (*state0).w += W[1].x+ K[51]; (*state1).w += (*state0).w; (*state0).w += (rotate((*state1).x,30U) ^ rotate((*state1).x,19U) ^ rotate((*state1).x,10U)); (*state0).w += bitselect((*state1).z,(*state1).y,((*state1).x^(*state1).z));;

  W[1].y += (rotate(W[0].w,15U) ^ rotate(W[0].w,13U) ^ (W[0].w>>10U)) + W[3].z + (rotate(W[1].z,25U) ^ rotate(W[1].z,14U) ^ (W[1].z>>3U));
  (*state0).z += (rotate((*state1).w,26U) ^ rotate((*state1).w,21U) ^ rotate((*state1).w,7U)); (*state0).z += bitselect((*state0).y,(*state0).x,(*state1).w); (*state0).z += W[1].y+ K[52]; (*state1).z += (*state0).z; (*state0).z += (rotate((*state0).w,30U) ^ rotate((*state0).w,19U) ^ rotate((*state0).w,10U)); (*state0).z += bitselect((*state1).y,(*state1).x,((*state0).w^(*state1).y));;

  W[1].z += (rotate(W[1].x,15U) ^ rotate(W[1].x,13U) ^ (W[1].x>>10U)) + W[3].w + (rotate(W[1].w,25U) ^ rotate(W[1].w,14U) ^ (W[1].w>>3U));
  (*state0).y += (rotate((*state1).z,26U) ^ rotate((*state1).z,21U) ^ rotate((*state1).z,7U)); (*state0).y += bitselect((*state0).x,(*state1).w,(*state1).z); (*state0).y += W[1].z+ K[53]; (*state1).y += (*state0).y; (*state0).y += (rotate((*state0).z,30U) ^ rotate((*state0).z,19U) ^ rotate((*state0).z,10U)); (*state0).y += bitselect((*state1).x,(*state0).w,((*state0).z^(*state1).x));;

  W[1].w += (rotate(W[1].y,15U) ^ rotate(W[1].y,13U) ^ (W[1].y>>10U)) + W[0].x + (rotate(W[2].x,25U) ^ rotate(W[2].x,14U) ^ (W[2].x>>3U));
  (*state0).x += (rotate((*state1).y,26U) ^ rotate((*state1).y,21U) ^ rotate((*state1).y,7U)); (*state0).x += bitselect((*state1).w,(*state1).z,(*state1).y); (*state0).x += W[1].w+ K[54]; (*state1).x += (*state0).x; (*state0).x += (rotate((*state0).y,30U) ^ rotate((*state0).y,19U) ^ rotate((*state0).y,10U)); (*state0).x += bitselect((*state0).w,(*state0).z,((*state0).y^(*state0).w));;

  W[2].x += (rotate(W[1].z,15U) ^ rotate(W[1].z,13U) ^ (W[1].z>>10U)) + W[0].y + (rotate(W[2].y,25U) ^ rotate(W[2].y,14U) ^ (W[2].y>>3U));
  (*state1).w += (rotate((*state1).x,26U) ^ rotate((*state1).x,21U) ^ rotate((*state1).x,7U)); (*state1).w += bitselect((*state1).z,(*state1).y,(*state1).x); (*state1).w += W[2].x+ K[55]; (*state0).w += (*state1).w; (*state1).w += (rotate((*state0).x,30U) ^ rotate((*state0).x,19U) ^ rotate((*state0).x,10U)); (*state1).w += bitselect((*state0).z,(*state0).y,((*state0).x^(*state0).z));;

  W[2].y += (rotate(W[1].w,15U) ^ rotate(W[1].w,13U) ^ (W[1].w>>10U)) + W[0].z + (rotate(W[2].z,25U) ^ rotate(W[2].z,14U) ^ (W[2].z>>3U));
  (*state1).z += (rotate((*state0).w,26U) ^ rotate((*state0).w,21U) ^ rotate((*state0).w,7U)); (*state1).z += bitselect((*state1).y,(*state1).x,(*state0).w); (*state1).z += W[2].y+ K[56]; (*state0).z += (*state1).z; (*state1).z += (rotate((*state1).w,30U) ^ rotate((*state1).w,19U) ^ rotate((*state1).w,10U)); (*state1).z += bitselect((*state0).y,(*state0).x,((*state1).w^(*state0).y));;

  W[2].z += (rotate(W[2].x,15U) ^ rotate(W[2].x,13U) ^ (W[2].x>>10U)) + W[0].w + (rotate(W[2].w,25U) ^ rotate(W[2].w,14U) ^ (W[2].w>>3U));
  (*state1).y += (rotate((*state0).z,26U) ^ rotate((*state0).z,21U) ^ rotate((*state0).z,7U)); (*state1).y += bitselect((*state1).x,(*state0).w,(*state0).z); (*state1).y += W[2].z+ K[57]; (*state0).y += (*state1).y; (*state1).y += (rotate((*state1).z,30U) ^ rotate((*state1).z,19U) ^ rotate((*state1).z,10U)); (*state1).y += bitselect((*state0).x,(*state1).w,((*state1).z^(*state0).x));;

  W[2].w += (rotate(W[2].y,15U) ^ rotate(W[2].y,13U) ^ (W[2].y>>10U)) + W[1].x + (rotate(W[3].x,25U) ^ rotate(W[3].x,14U) ^ (W[3].x>>3U));
  (*state1).x += (rotate((*state0).y,26U) ^ rotate((*state0).y,21U) ^ rotate((*state0).y,7U)); (*state1).x += bitselect((*state0).w,(*state0).z,(*state0).y); (*state1).x += W[2].w+ K[58]; (*state0).x += (*state1).x; (*state1).x += (rotate((*state1).y,30U) ^ rotate((*state1).y,19U) ^ rotate((*state1).y,10U)); (*state1).x += bitselect((*state1).w,(*state1).z,((*state1).y^(*state1).w));;

  W[3].x += (rotate(W[2].z,15U) ^ rotate(W[2].z,13U) ^ (W[2].z>>10U)) + W[1].y + (rotate(W[3].y,25U) ^ rotate(W[3].y,14U) ^ (W[3].y>>3U));
  (*state0).w += (rotate((*state0).x,26U) ^ rotate((*state0).x,21U) ^ rotate((*state0).x,7U)); (*state0).w += bitselect((*state0).z,(*state0).y,(*state0).x); (*state0).w += W[3].x+ K[59]; (*state1).w += (*state0).w; (*state0).w += (rotate((*state1).x,30U) ^ rotate((*state1).x,19U) ^ rotate((*state1).x,10U)); (*state0).w += bitselect((*state1).z,(*state1).y,((*state1).x^(*state1).z));;

  W[3].y += (rotate(W[2].w,15U) ^ rotate(W[2].w,13U) ^ (W[2].w>>10U)) + W[1].z + (rotate(W[3].z,25U) ^ rotate(W[3].z,14U) ^ (W[3].z>>3U));
  (*state0).z += (rotate((*state1).w,26U) ^ rotate((*state1).w,21U) ^ rotate((*state1).w,7U)); (*state0).z += bitselect((*state0).y,(*state0).x,(*state1).w); (*state0).z += W[3].y+ K[60]; (*state1).z += (*state0).z; (*state0).z += (rotate((*state0).w,30U) ^ rotate((*state0).w,19U) ^ rotate((*state0).w,10U)); (*state0).z += bitselect((*state1).y,(*state1).x,((*state0).w^(*state1).y));;

  W[3].z += (rotate(W[3].x,15U) ^ rotate(W[3].x,13U) ^ (W[3].x>>10U)) + W[1].w + (rotate(W[3].w,25U) ^ rotate(W[3].w,14U) ^ (W[3].w>>3U));
  (*state0).y += (rotate((*state1).z,26U) ^ rotate((*state1).z,21U) ^ rotate((*state1).z,7U)); (*state0).y += bitselect((*state0).x,(*state1).w,(*state1).z); (*state0).y += W[3].z+ K[61]; (*state1).y += (*state0).y; (*state0).y += (rotate((*state0).z,30U) ^ rotate((*state0).z,19U) ^ rotate((*state0).z,10U)); (*state0).y += bitselect((*state1).x,(*state0).w,((*state0).z^(*state1).x));;

  W[3].w += (rotate(W[3].y,15U) ^ rotate(W[3].y,13U) ^ (W[3].y>>10U)) + W[2].x + (rotate(W[0].x,25U) ^ rotate(W[0].x,14U) ^ (W[0].x>>3U));
  (*state0).x += (rotate((*state1).y,26U) ^ rotate((*state1).y,21U) ^ rotate((*state1).y,7U)); (*state0).x += bitselect((*state1).w,(*state1).z,(*state1).y); (*state0).x += W[3].w+ K[62]; (*state1).x += (*state0).x; (*state0).x += (rotate((*state0).y,30U) ^ rotate((*state0).y,19U) ^ rotate((*state0).y,10U)); (*state0).x += bitselect((*state0).w,(*state0).z,((*state0).y^(*state0).w));;
# 648 "/usr/local/share/xpmminer/sha256.h"
  *state0 += (uint4)(K[73], K[77], K[78], K[79]);
  *state1 += (uint4)(K[66], K[67], K[80], K[81]);
}

void sha256SwapByteOrder(uint4 *data)
{
  *data = (uint4){
    (rotate((*data).x & ES[0],24U)|rotate((*data).x & ES[1],8U)),
    (rotate((*data).y & ES[0],24U)|rotate((*data).y & ES[1],8U)),
    (rotate((*data).z & ES[0],24U)|rotate((*data).z & ES[1],8U)),
    (rotate((*data).w & ES[0],24U)|rotate((*data).w & ES[1],8U))
  };
}
# 6 "/tmp/comgr-7f7e55/input/CompileSource" 2
# 1 "/usr/local/share/xpmminer/fmt.h" 1
# 14 "/usr/local/share/xpmminer/fmt.h"
#pragma pack(push, 1)
struct GPUNonceAndHash {
  uint4 hash[2*256];
  uint32_t nonce[256];
  uint32_t currentNonce;
  uint32_t totalNonces;
  uint32_t align[2];
};

struct FermatQueue {
  uint32_t position;
  uint32_t size;
  uint32_t _align1[2];

  uint4 chainOrigins[3*(16*256)];
  uint32_t multipliers[(16*256)];
  uint32_t chainLengths[(16*256)];
  uint32_t nonces[(16*256)];
};

struct FermatTestResults {
  uint32_t size;
  uint32_t _align1[3];
  uint32_t resultTypes[256*16];
  uint32_t resultMultipliers[256*16];
  uint32_t resultChainLength[256*16];
  uint32_t resultNonces[256*16];
};
#pragma pack(pop)
# 7 "/tmp/comgr-7f7e55/input/CompileSource" 2
#pragma OPENCL EXTENSION cl_amd_printf : enable
# 29 "/tmp/comgr-7f7e55/input/CompileSource"
__constant uint32_t binvert_limb_table[128] = {
  0x01, 0xAB, 0xCD, 0xB7, 0x39, 0xA3, 0xC5, 0xEF,
  0xF1, 0x1B, 0x3D, 0xA7, 0x29, 0x13, 0x35, 0xDF,
  0xE1, 0x8B, 0xAD, 0x97, 0x19, 0x83, 0xA5, 0xCF,
  0xD1, 0xFB, 0x1D, 0x87, 0x09, 0xF3, 0x15, 0xBF,
  0xC1, 0x6B, 0x8D, 0x77, 0xF9, 0x63, 0x85, 0xAF,
  0xB1, 0xDB, 0xFD, 0x67, 0xE9, 0xD3, 0xF5, 0x9F,
  0xA1, 0x4B, 0x6D, 0x57, 0xD9, 0x43, 0x65, 0x8F,
  0x91, 0xBB, 0xDD, 0x47, 0xC9, 0xB3, 0xD5, 0x7F,
  0x81, 0x2B, 0x4D, 0x37, 0xB9, 0x23, 0x45, 0x6F,
  0x71, 0x9B, 0xBD, 0x27, 0xA9, 0x93, 0xB5, 0x5F,
  0x61, 0x0B, 0x2D, 0x17, 0x99, 0x03, 0x25, 0x4F,
  0x51, 0x7B, 0x9D, 0x07, 0x89, 0x73, 0x95, 0x3F,
  0x41, 0xEB, 0x0D, 0xF7, 0x79, 0xE3, 0x05, 0x2F,
  0x31, 0x5B, 0x7D, 0xE7, 0x69, 0x53, 0x75, 0x1F,
  0x21, 0xCB, 0xED, 0xD7, 0x59, 0xC3, 0xE5, 0x0F,
  0x11, 0x3B, 0x5D, 0xC7, 0x49, 0x33, 0x55, 0xFF
};


void dbgPrint_v4(uint4 Reg)
{
  printf("%08X %08X %08X %08X ", Reg.x, Reg.y, Reg.z, Reg.w);
}
# 62 "/tmp/comgr-7f7e55/input/CompileSource"
uint32_t longModuloByMul256(uint4 nl0, uint4 nl1,
                            uint32_t divisor,
                            uint64_t inversedMultiplier,
                            uint32_t shift)
{
  uint64_t mod = 0;
  { uint64_t dividend = (mod << 32) + nl1.w; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl1.z; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl1.y; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl1.x; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl0.w; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl0.z; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl0.y; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl0.x; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  return mod;
}

uint32_t longModuloByMul384(uint4 nl0, uint4 nl1, uint4 nl2,
                            uint32_t divisor,
                            uint64_t inversedMultiplier,
                            uint32_t shift)
{
  uint64_t mod = 0;
  { uint64_t dividend = (mod << 32) + nl2.w; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl2.z; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl2.y; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl2.x; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl1.w; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl1.z; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl1.y; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl1.x; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl0.w; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl0.z; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl0.y; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  { uint64_t dividend = (mod << 32) + nl0.x; uint64_t quotient = mul_hi(dividend, inversedMultiplier) >> shift; mod = dividend - quotient*divisor;};
  return mod;
}


uint32_t intInvert(uint32_t a, uint32_t mod)
{
  uint32_t rem0 = mod, rem1 = a % mod, rem2;
  uint32_t aux0 = 0, aux1 = 1, aux2;
  uint32_t quotient, inverse;

  while (1) {
    if (rem1 <= 1) {
      inverse = aux1;
      break;
    }

    rem2 = rem0 % rem1;
    quotient = rem0 / rem1;
    aux2 = -quotient * aux1 + aux0;

    if (rem2 <= 1) {
      inverse = aux2;
      break;
    }

    rem0 = rem1 % rem2;
    quotient = rem1 / rem2;
    aux0 = -quotient * aux2 + aux1;

    if (rem0 <= 1) {
      inverse = aux0;
      break;
    }

    rem1 = rem2 % rem0;
    quotient = rem2 / rem0;
    aux1 = -quotient * aux0 + aux2;
  }

  return (inverse + mod) % mod;
}

unsigned int calculateOffset(unsigned int currentPrime,
                             unsigned int currentPrimeMod,
                             unsigned int offset)
{
  return offset >= currentPrimeMod ?
    offset - currentPrimeMod : currentPrime + offset - currentPrimeMod;
}


void clFillMemoryByGroup(__global void *buffer, unsigned size)
{
  __global uint32_t *ptr32 = (__global uint32_t*)buffer;
  for (unsigned i = get_local_id(0); i < size/4; i += 256)
    ptr32[i] = 0xFFFFFFFF;
}

void flushLayer(unsigned layer,
                __global uint8 *cunningham1,
                __global uint8 *cunningham2,
                __global uint8 *bitwin,
                uint8 CR1,
                uint8 CR2,
                unsigned threadId)
{
  if (layer < 10/2) {
    cunningham1[threadId] &= CR1;
    cunningham2[threadId] &= CR2;

    CR1 &= CR2;
    bitwin[threadId] &= CR1;
  } else if (layer < (10 + 1)/2) {
    cunningham1[threadId] &= CR1;
    cunningham2[threadId] &= CR2;
    bitwin[threadId] &= CR1;
  } else if (layer < 10) {
    cunningham1[threadId] &= CR1;
    cunningham2[threadId] &= CR2;
  }
}


void weave(uint4 M0, uint4 M1, uint4 M2,
           __global uint32_t *cunningham1Bitfield,
           __global uint32_t *cunningham2Bitfield,
           __global uint32_t *bitwinBitfield,
           __local uint8_t *localCunningham1,
           __local uint8_t *localCunningham2,
           __constant uint32_t *primes,
           __global uint64_t *multipliers64,
           __global uint32_t *offsets64,
           unsigned roundsNum)
{
  const unsigned primesPerThread = 7936 / 256;
  const unsigned layersNum = 10 + 9;
  const unsigned threadId = get_local_id(0);
  unsigned sieveBytes = 8192 * roundsNum / 8;
  unsigned sieveWords = sieveBytes / 4;

  uint32_t inverseModulos[256];
  uint32_t inverseModulosCurrent[7936 / 256];


  clFillMemoryByGroup(cunningham1Bitfield, sieveBytes);
  clFillMemoryByGroup(cunningham2Bitfield, sieveBytes);
  clFillMemoryByGroup(bitwinBitfield, sieveBytes);
  for (unsigned extNum = 1; extNum <= 9; extNum++) {
    clFillMemoryByGroup(cunningham1Bitfield + extNum*sieveWords + sieveWords/2, sieveBytes/2);
    clFillMemoryByGroup(cunningham2Bitfield + extNum*sieveWords + sieveWords/2, sieveBytes/2);
    clFillMemoryByGroup(bitwinBitfield + extNum*sieveWords + sieveWords/2, sieveBytes/2);
  }

  unsigned primeIdx = 19 +threadId;
  for (unsigned j = 0; j < 7936/get_local_size(0); j++, primeIdx += 256) {
    unsigned currentPrime = primes[primeIdx];
    unsigned mod = longModuloByMul384(M0, M1, M2,
                                  currentPrime,
                                  multipliers64[primeIdx],
                                  offsets64[primeIdx]);

    inverseModulos[j] = intInvert(mod, currentPrime);
  }

  const unsigned L1CacheWords = 8192/4;
  __local uint32_t *localCunningham1_32 = (__local uint32_t*)localCunningham1;
  __local uint32_t *localCunningham2_32 = (__local uint32_t*)localCunningham2;

  for (unsigned round = 0; round < roundsNum; round += 8) {
    unsigned lowIdx = 8192 * round;
    for (unsigned i = 0; i < primesPerThread; i++)
      inverseModulosCurrent[i] = inverseModulos[i];

    for (unsigned layer = 0; layer < layersNum; layer++) {
      if (layer >= 10 && round < roundsNum/2)
        break;

      barrier(CLK_LOCAL_MEM_FENCE);
      for (unsigned i = 0, index = get_local_id(0); i < L1CacheWords/256; i++, index += 256) {
        uint32_t X = 0xFFFFFFFF;
        localCunningham1_32[index] = X;
        localCunningham2_32[index] = X;
      }

      unsigned primeIdx;
      for (unsigned j = 0, primeIdx = 19 +threadId; j < (2048)/get_local_size(0); j++, primeIdx += 256) {
        unsigned offset;
        unsigned offset2;
        const uint32_t currentPrime = primes[primeIdx];
        const uint32_t inverseModulo = inverseModulosCurrent[j];
        const uint32_t currentPrimeMod = lowIdx % currentPrime;

        offset = calculateOffset(currentPrime, currentPrimeMod, inverseModulo);
        offset2 = calculateOffset(currentPrime, currentPrimeMod, currentPrime - inverseModulo);

        for (unsigned iter = 0; iter < 8; iter++) {
          barrier(CLK_LOCAL_MEM_FENCE);
          uint8_t fill = ~(1 << iter);

          unsigned maxOffset = max(offset, offset2);
          while (maxOffset < 8192) {
            localCunningham1[offset] &= fill;
            localCunningham2[offset2] &= fill;
            offset += currentPrime;
            offset2 += currentPrime;
            maxOffset += currentPrime;
          }

          if (offset < 8192) {
            localCunningham1[offset] &= fill;
            offset += currentPrime;
          }

          if (offset2 < 8192) {
            localCunningham2[offset2] &= fill;
            offset2 += currentPrime;
          }

          offset -= 8192;
          offset2 -= 8192;
        }

        inverseModulosCurrent[j] = (inverseModulo & 0x1) ?
          (inverseModulo + currentPrime) / 2 : inverseModulo / 2;
      }


      for (unsigned j = (2048)/256,
             primeIdx = (2048)+19 +threadId;
           j < primesPerThread;
           j++, primeIdx += 256) {
        const uint32_t currentPrime = primes[primeIdx];
        const uint32_t currentPrimeMod = lowIdx % currentPrime;
        const uint32_t inverseModulo = inverseModulosCurrent[j];

        unsigned offset = calculateOffset(currentPrime, currentPrimeMod, inverseModulo);
        unsigned offset2 = calculateOffset(currentPrime, currentPrimeMod, currentPrime - inverseModulo);

        for (unsigned iter = 0; iter < 8; iter++) {
          uint8_t fill = ~(1 << iter);
          if (offset < 8192) {
            localCunningham1[offset] &= fill;
            offset += currentPrime;
          }
          if (offset2 < 8192) {
            localCunningham2[offset2] &= fill;
            offset2 += currentPrime;
          }

          offset -= 8192;
          offset2 -= 8192;
        }

        inverseModulosCurrent[j] = (inverseModulo & 0x1) ?
          (inverseModulo + currentPrime) / 2 : inverseModulo / 2;
      }

      barrier(CLK_LOCAL_MEM_FENCE);


      __global uint32_t *cunningham1 = cunningham1Bitfield + lowIdx/32;
      __global uint32_t *cunningham2 = cunningham2Bitfield + lowIdx/32;
      __global uint32_t *bitwin = bitwinBitfield + lowIdx/32;

      uint8 CR1 = vload8(threadId, localCunningham1_32);
      uint8 CR2 = vload8(threadId, localCunningham2_32);

      flushLayer(layer, cunningham1, cunningham2, bitwin, CR1, CR2, threadId);


      if (round < roundsNum/2)
        continue;

      unsigned extNumMin = layer < 10 ? 1 : layer - 10 + 1;
      unsigned extNumMax = layer < 9 ? layer : 9;
      for (unsigned extNum = extNumMin; extNum <= extNumMax; extNum++) {
        __global uint32_t *extCunningham1 = cunningham1Bitfield + extNum*sieveWords + lowIdx/32;
        __global uint32_t *extCunningham2 = cunningham2Bitfield + extNum*sieveWords + lowIdx/32;
        __global uint32_t *extBitwin = bitwinBitfield + extNum*sieveWords + lowIdx/32;
        flushLayer(layer - extNum, extCunningham1, extCunningham2, extBitwin, CR1, CR2, threadId);
      }
    }
  }
}


__kernel void sieveBenchmark(__global uint32_t *fixedMultipliers,
                             __global uint32_t *cunningham1Bitfield,
                             __global uint32_t *cunningham2Bitfield,
                             __global uint32_t *bitwinBitfield,
                             __constant uint32_t *primes,
                             __global uint64_t *multipliers64,
                             __global uint32_t *offsets64,
                             unsigned roundsNum)
{
  __local uint8_t localCunningham1[8192];
  __local uint8_t localCunningham2[8192];

  __global uint4 *M = (__global uint4*)(fixedMultipliers + get_group_id(0) * (12));
  weave(M[0], M[1], M[2],
        cunningham1Bitfield + get_group_id(0) * ((8192*(256))*(9 +1))/32,
        cunningham2Bitfield + get_group_id(0) * ((8192*(256))*(9 +1))/32,
        bitwinBitfield + get_group_id(0) * ((8192*(256))*(9 +1))/32,
        localCunningham1,
        localCunningham2,
        primes,
        multipliers64,
        offsets64,
        roundsNum);

  return;
}

uint32_t add128(uint4 *A, uint4 B)
{
  *A += B;
  uint4 carry = -convert_uint4((*A) < B);

  (*A).y += carry.x; carry.y += ((*A).y < carry.x);
  (*A).z += carry.y; carry.z += ((*A).z < carry.y);
  (*A).w += carry.z;
  return carry.w + ((*A).w < carry.z);
}

uint32_t add128Carry(uint4 *A, uint4 B, uint32_t externalCarry)
{
  *A += B;
  uint4 carry = -convert_uint4((*A) < B);

  (*A).x += externalCarry; carry.x += ((*A).x < externalCarry);
  (*A).y += carry.x; carry.y += ((*A).y < carry.x);
  (*A).z += carry.y; carry.z += ((*A).z < carry.y);
  (*A).w += carry.z;
  return carry.w + ((*A).w < carry.z);
}

uint32_t add256(uint4 *a0, uint4 *a1, uint4 b0, uint4 b1)
{
  return add128Carry(a1, b1, add128(a0, b0));
}

uint32_t add384(uint4 *a0, uint4 *a1, uint4 *a2, uint4 b0, uint4 b1, uint4 b2)
{
  return add128Carry(a2, b2, add128Carry(a1, b1, add128(a0, b0)));
}

uint32_t add512(uint4 *a0, uint4 *a1, uint4 *a2, uint4 *a3, uint4 b0, uint4 b1, uint4 b2, uint4 b3)
{
  return add128Carry(a3, b3, add128Carry(a2, b2, add128Carry(a1, b1, add128(a0, b0))));
}

uint32_t sub64Borrow(uint2 *A, uint2 B, uint32_t externalBorrow)
{
  uint2 borrow = -convert_uint2((*A) < B);
  *A -= B;

  borrow.x += (*A).x < externalBorrow; (*A).x -= externalBorrow;
  borrow.y += (*A).y < borrow.x; (*A).y -= borrow.x;
  return borrow.y;
}

uint32_t sub128(uint4 *A, uint4 B)
{
  uint4 borrow = -convert_uint4((*A) < B);
  *A -= B;

  borrow.y += (*A).y < borrow.x; (*A).y -= borrow.x;
  borrow.z += (*A).z < borrow.y; (*A).z -= borrow.y;
  borrow.w += (*A).w < borrow.z; (*A).w -= borrow.z;
  return borrow.w;
}

uint32_t sub128Borrow(uint4 *A, uint4 B, uint32_t externalBorrow)
{
  uint4 borrow = -convert_uint4((*A) < B);
  *A -= B;

  borrow.x += (*A).x < externalBorrow; (*A).x -= externalBorrow;
  borrow.y += (*A).y < borrow.x; (*A).y -= borrow.x;
  borrow.z += (*A).z < borrow.y; (*A).z -= borrow.y;
  borrow.w += (*A).w < borrow.z; (*A).w -= borrow.z;
  return borrow.w;
}

uint32_t sub256(uint4 *a0, uint4 *a1, uint4 b0, uint4 b1)
{
  return sub128Borrow(a1, b1, sub128(a0, b0));
}

uint32_t sub384(uint4 *a0, uint4 *a1, uint4 *a2, uint4 b0, uint4 b1, uint4 b2)
{
  return sub128Borrow(a2, b2, sub128Borrow(a1, b1, sub128(a0, b0)));
}

uint32_t sub448(uint4 *a0, uint4 *a1, uint4 *a2, uint2 *a3, uint4 b0, uint4 b1, uint4 b2, uint2 b3)
{
  return sub64Borrow(a3, b3, sub128Borrow(a2, b2, sub128Borrow(a1, b1, sub128(a0, b0))));
}

void mul128round(uint4 op1l0, uint32_t m1, uint32_t m2,
                 uint64_t *R0, uint64_t *R1, uint64_t *R2, uint64_t *R3)
{
  uint4 l0 = mul_hi(op1l0, m1);
  uint4 l1 = op1l0 * m2;

  *R0 += l0.x; *R0 += l1.x;
  *R1 += l0.y; *R1 += l1.y; *R1 += (*R0 >> 32);
  *R2 += l0.z; *R2 += l1.z;
  *R3 += l0.w; *R3 += l1.w;
}

void mul128schoolBook_v3(uint4 op1l0, uint4 op2l0, uint4 *rl0, uint4 *rl1)
{





  ulong R0x = op1l0.x * op2l0.x;
  ulong R0y = op1l0.y * op2l0.x;
  ulong R0z = op1l0.z * op2l0.x;
  ulong R0w = op1l0.w * op2l0.x;
  ulong R1x = mul_hi(op1l0.x, op2l0.w);
  ulong R1y = mul_hi(op1l0.y, op2l0.w);
  ulong R1z = mul_hi(op1l0.z, op2l0.w);
  ulong R1w = mul_hi(op1l0.w, op2l0.w);

  mul128round(op1l0, op2l0.x, op2l0.y, &R0y, &R0z, &R0w, &R1x);
  mul128round(op1l0, op2l0.y, op2l0.z, &R0z, &R0w, &R1x, &R1y);
  mul128round(op1l0, op2l0.z, op2l0.w, &R0w, &R1x, &R1y, &R1z);
  R1y += (R1x >> 32);
  R1z += (R1y >> 32);
  R1w += (R1z >> 32);
  *rl0 = (uint4){R0x, R0y, R0z, R0w};
  *rl1 = (uint4){R1x, R1y, R1z, R1w};




}


void mul256round_v3(uint4 op1l0, uint4 op1l1, uint32_t m1, uint32_t m2,
                    uint64_t *R0, uint64_t *R1, uint64_t *R2, uint64_t *R3,
                    uint64_t *R4, uint64_t *R5, uint64_t *R6, uint64_t *R7)
{
  uint4 m1l0 = mul_hi(op1l0, m1);
  uint4 m1l1 = mul_hi(op1l1, m1);
  uint4 m2l0 = op1l0 * m2;
  uint4 m2l1 = op1l1 * m2;

  union {
    uint2 v32;
    ulong v64;
  } Int;
  *R0 += m1l0.x; *R0 += m2l0.x;
  *R1 += m1l0.y; *R1 += m2l0.y; Int.v64 = *R0; *R1 += Int.v32.y;
  *R2 += m1l0.z; *R2 += m2l0.z;
  *R3 += m1l0.w; *R3 += m2l0.w;
  *R4 += m1l1.x; *R4 += m2l1.x;
  *R5 += m1l1.y; *R5 += m2l1.y;
  *R6 += m1l1.z; *R6 += m2l1.z;
  *R7 += m1l1.w; *R7 += m2l1.w;
}


void mul384round_v3(uint4 op1l0, uint4 op1l1, uint4 op1l2, uint32_t m1, uint32_t m2,
                    uint64_t *R0, uint64_t *R1, uint64_t *R2, uint64_t *R3,
                    uint64_t *R4, uint64_t *R5, uint64_t *R6, uint64_t *R7,
                    uint64_t *R8, uint64_t *R9, uint64_t *R10, uint64_t *R11)
{
  uint4 m1l0 = mul_hi(op1l0, m1);
  uint4 m1l1 = mul_hi(op1l1, m1);
  uint4 m1l2 = mul_hi(op1l2, m1);
  uint4 m2l0 = op1l0 * m2;
  uint4 m2l1 = op1l1 * m2;
  uint4 m2l2 = op1l2 * m2;

  union {
    uint2 v32;
    ulong v64;
  } Int;
  *R0 += m1l0.x; *R0 += m2l0.x;
  *R1 += m1l0.y; *R1 += m2l0.y; Int.v64 = *R0; *R1 += Int.v32.y;
  *R2 += m1l0.z; *R2 += m2l0.z;
  *R3 += m1l0.w; *R3 += m2l0.w;
  *R4 += m1l1.x; *R4 += m2l1.x;
  *R5 += m1l1.y; *R5 += m2l1.y;
  *R6 += m1l1.z; *R6 += m2l1.z;
  *R7 += m1l1.w; *R7 += m2l1.w;
  *R8 += m1l2.x; *R8 += m2l2.x;
  *R9 += m1l2.y; *R9 += m2l2.y;
  *R10 += m1l2.z; *R10 += m2l2.z;
  *R11 += m1l2.w; *R11 += m2l2.w;
}


void mul448round_v3(uint4 op1l0, uint4 op1l1, uint4 op1l2, uint2 op1l3, uint32_t m1, uint32_t m2,
                    uint64_t *R0, uint64_t *R1, uint64_t *R2, uint64_t *R3,
                    uint64_t *R4, uint64_t *R5, uint64_t *R6, uint64_t *R7,
                    uint64_t *R8, uint64_t *R9, uint64_t *R10, uint64_t *R11,
                    uint64_t *R12, uint64_t *R13)
{
  uint4 m1l0 = mul_hi(op1l0, m1);
  uint4 m1l1 = mul_hi(op1l1, m1);
  uint4 m1l2 = mul_hi(op1l2, m1);
  uint2 m1l3 = mul_hi(op1l3, m1);
  uint4 m2l0 = op1l0 * m2;
  uint4 m2l1 = op1l1 * m2;
  uint4 m2l2 = op1l2 * m2;
  uint2 m2l3 = op1l3 * m2;

  union {
    uint2 v32;
    ulong v64;
  } Int;
  *R0 += m1l0.x; *R0 += m2l0.x;
  *R1 += m1l0.y; *R1 += m2l0.y; Int.v64 = *R0; *R1 += Int.v32.y;
  *R2 += m1l0.z; *R2 += m2l0.z;
  *R3 += m1l0.w; *R3 += m2l0.w;
  *R4 += m1l1.x; *R4 += m2l1.x;
  *R5 += m1l1.y; *R5 += m2l1.y;
  *R6 += m1l1.z; *R6 += m2l1.z;
  *R7 += m1l1.w; *R7 += m2l1.w;
  *R8 += m1l2.x; *R8 += m2l2.x;
  *R9 += m1l2.y; *R9 += m2l2.y;
  *R10 += m1l2.z; *R10 += m2l2.z;
  *R11 += m1l2.w; *R11 += m2l2.w;
  *R12 += m1l3.x; *R12 += m2l3.x;
  *R13 += m1l3.y; *R13 += m2l3.y;
}


void mul256schoolBook_v3(uint4 op1l0, uint4 op1l1,
                         uint4 op2l0, uint4 op2l1,
                         uint4 *rl0, uint4 *rl1, uint4 *rl2, uint4 *rl3)
{
# 602 "/tmp/comgr-7f7e55/input/CompileSource"
  ulong R0x = op1l0.x * op2l0.x;
  ulong R0y = op1l0.y * op2l0.x;
  ulong R0z = op1l0.z * op2l0.x;
  ulong R0w = op1l0.w * op2l0.x;
  ulong R1x = op1l1.x * op2l0.x;
  ulong R1y = op1l1.y * op2l0.x;
  ulong R1z = op1l1.z * op2l0.x;
  ulong R1w = op1l1.w * op2l0.x;
  ulong R2x = mul_hi(op1l0.x, op2l1.w);
  ulong R2y = mul_hi(op1l0.y, op2l1.w);
  ulong R2z = mul_hi(op1l0.z, op2l1.w);
  ulong R2w = mul_hi(op1l0.w, op2l1.w);
  ulong R3x = mul_hi(op1l1.x, op2l1.w);
  ulong R3y = mul_hi(op1l1.y, op2l1.w);
  ulong R3z = mul_hi(op1l1.z, op2l1.w);
  ulong R3w = mul_hi(op1l1.w, op2l1.w);

  mul256round_v3(op1l0, op1l1, op2l0.x, op2l0.y, &R0y, &R0z, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x);
  mul256round_v3(op1l0, op1l1, op2l0.y, op2l0.z, &R0z, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y);
  mul256round_v3(op1l0, op1l1, op2l0.z, op2l0.w, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z);
  mul256round_v3(op1l0, op1l1, op2l0.w, op2l1.x, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w);
  mul256round_v3(op1l0, op1l1, op2l1.x, op2l1.y, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x);
  mul256round_v3(op1l0, op1l1, op2l1.y, op2l1.z, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y);
  mul256round_v3(op1l0, op1l1, op2l1.z, op2l1.w, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z);

  union {
    uint2 v32;
    ulong v64;
  } Int;

  Int.v64 = R2x; R2y += Int.v32.y;
  Int.v64 = R2y; R2z += Int.v32.y;
  Int.v64 = R2z; R2w += Int.v32.y;
  Int.v64 = R2w; R3x += Int.v32.y;
  Int.v64 = R3x; R3y += Int.v32.y;
  Int.v64 = R3y; R3z += Int.v32.y;
  Int.v64 = R3z; R3w += Int.v32.y;

  *rl0 = (uint4){R0x, R0y, R0z, R0w};
  *rl1 = (uint4){R1x, R1y, R1z, R1w};
  *rl2 = (uint4){R2x, R2y, R2z, R2w};
  *rl3 = (uint4){R3x, R3y, R3z, R3w};
# 652 "/tmp/comgr-7f7e55/input/CompileSource"
}


void mul384schoolBook_v3(uint4 op1l0, uint4 op1l1, uint4 op1l2,
                         uint4 op2l0, uint4 op2l1, uint4 op2l2,
                         uint4 *rl0, uint4 *rl1, uint4 *rl2, uint4 *rl3, uint4 *rl4, uint4 *rl5)
{
# 671 "/tmp/comgr-7f7e55/input/CompileSource"
  ulong R0x = op1l0.x * op2l0.x;
  ulong R0y = op1l0.y * op2l0.x;
  ulong R0z = op1l0.z * op2l0.x;
  ulong R0w = op1l0.w * op2l0.x;
  ulong R1x = op1l1.x * op2l0.x;
  ulong R1y = op1l1.y * op2l0.x;
  ulong R1z = op1l1.z * op2l0.x;
  ulong R1w = op1l1.w * op2l0.x;
  ulong R2x = op1l2.x * op2l0.x;
  ulong R2y = op1l2.y * op2l0.x;
  ulong R2z = op1l2.z * op2l0.x;
  ulong R2w = op1l2.w * op2l0.x;
  ulong R3x = mul_hi(op1l0.x, op2l2.w);
  ulong R3y = mul_hi(op1l0.y, op2l2.w);
  ulong R3z = mul_hi(op1l0.z, op2l2.w);
  ulong R3w = mul_hi(op1l0.w, op2l2.w);
  ulong R4x = mul_hi(op1l1.x, op2l2.w);
  ulong R4y = mul_hi(op1l1.y, op2l2.w);
  ulong R4z = mul_hi(op1l1.z, op2l2.w);
  ulong R4w = mul_hi(op1l1.w, op2l2.w);
  ulong R5x = mul_hi(op1l2.x, op2l2.w);
  ulong R5y = mul_hi(op1l2.y, op2l2.w);
  ulong R5z = mul_hi(op1l2.z, op2l2.w);
  ulong R5w = mul_hi(op1l2.w, op2l2.w);

  mul384round_v3(op1l0, op1l1, op1l2, op2l0.x, op2l0.y, &R0y, &R0z, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x);
  mul384round_v3(op1l0, op1l1, op1l2, op2l0.y, op2l0.z, &R0z, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y);
  mul384round_v3(op1l0, op1l1, op1l2, op2l0.z, op2l0.w, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z);
  mul384round_v3(op1l0, op1l1, op1l2, op2l0.w, op2l1.x, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w);
  mul384round_v3(op1l0, op1l1, op1l2, op2l1.x, op2l1.y, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x);
  mul384round_v3(op1l0, op1l1, op1l2, op2l1.y, op2l1.z, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y);
  mul384round_v3(op1l0, op1l1, op1l2, op2l1.z, op2l1.w, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z);
  mul384round_v3(op1l0, op1l1, op1l2, op2l1.w, op2l2.x, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w);
  mul384round_v3(op1l0, op1l1, op1l2, op2l2.x, op2l2.y, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x);
  mul384round_v3(op1l0, op1l1, op1l2, op2l2.y, op2l2.z, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y);
  mul384round_v3(op1l0, op1l1, op1l2, op2l2.z, op2l2.w, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y, &R5z);

  union {
    uint2 v32;
    ulong v64;
  } Int;

  Int.v64 = R3x; R3y += Int.v32.y;
  Int.v64 = R3y; R3z += Int.v32.y;
  Int.v64 = R3z; R3w += Int.v32.y;
  Int.v64 = R3w; R4x += Int.v32.y;
  Int.v64 = R4x; R4y += Int.v32.y;
  Int.v64 = R4y; R4z += Int.v32.y;
  Int.v64 = R4z; R4w += Int.v32.y;
  Int.v64 = R4w; R5x += Int.v32.y;
  Int.v64 = R5x; R5y += Int.v32.y;
  Int.v64 = R5y; R5z += Int.v32.y;
  Int.v64 = R5z; R5w += Int.v32.y;

  *rl0 = (uint4){R0x, R0y, R0z, R0w};
  *rl1 = (uint4){R1x, R1y, R1z, R1w};
  *rl2 = (uint4){R2x, R2y, R2z, R2w};
  *rl3 = (uint4){R3x, R3y, R3z, R3w};
  *rl4 = (uint4){R4x, R4y, R4z, R4w};
  *rl5 = (uint4){R5x, R5y, R5z, R5w};
# 744 "/tmp/comgr-7f7e55/input/CompileSource"
}

void mul448schoolBook_v3(uint4 op1l0, uint4 op1l1, uint4 op1l2, uint2 op1l3,
                         uint4 op2l0, uint4 op2l1, uint4 op2l2, uint2 op2l3,
                         uint4 *rl0, uint4 *rl1, uint4 *rl2, uint4 *rl3, uint4 *rl4, uint4 *rl5, uint4 *rl6)
{
# 765 "/tmp/comgr-7f7e55/input/CompileSource"
  ulong R0x = op1l0.x * op2l0.x;
  ulong R0y = op1l0.y * op2l0.x;
  ulong R0z = op1l0.z * op2l0.x;
  ulong R0w = op1l0.w * op2l0.x;
  ulong R1x = op1l1.x * op2l0.x;
  ulong R1y = op1l1.y * op2l0.x;
  ulong R1z = op1l1.z * op2l0.x;
  ulong R1w = op1l1.w * op2l0.x;
  ulong R2x = op1l2.x * op2l0.x;
  ulong R2y = op1l2.y * op2l0.x;
  ulong R2z = op1l2.z * op2l0.x;
  ulong R2w = op1l2.w * op2l0.x;
  ulong R3x = op1l3.x * op2l0.x;
  ulong R3y = op1l3.y * op2l0.x;
  ulong R3z = mul_hi(op1l0.x, op2l3.y);
  ulong R3w = mul_hi(op1l0.y, op2l3.y);
  ulong R4x = mul_hi(op1l0.z, op2l3.y);
  ulong R4y = mul_hi(op1l0.w, op2l3.y);
  ulong R4z = mul_hi(op1l1.x, op2l3.y);
  ulong R4w = mul_hi(op1l1.y, op2l3.y);
  ulong R5x = mul_hi(op1l1.z, op2l3.y);
  ulong R5y = mul_hi(op1l1.w, op2l3.y);
  ulong R5z = mul_hi(op1l2.x, op2l3.y);
  ulong R5w = mul_hi(op1l2.y, op2l3.y);
  ulong R6x = mul_hi(op1l2.z, op2l3.y);
  ulong R6y = mul_hi(op1l2.w, op2l3.y);
  ulong R6z = mul_hi(op1l3.x, op2l3.y);
  ulong R6w = mul_hi(op1l3.y, op2l3.y);

  mul448round_v3(op1l0, op1l1, op1l2, op1l3, op2l0.x, op2l0.y, &R0y, &R0z, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z);
  mul448round_v3(op1l0, op1l1, op1l2, op1l3, op2l0.y, op2l0.z, &R0z, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w);
  mul448round_v3(op1l0, op1l1, op1l2, op1l3, op2l0.z, op2l0.w, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x);
  mul448round_v3(op1l0, op1l1, op1l2, op1l3, op2l0.w, op2l1.x, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y);
  mul448round_v3(op1l0, op1l1, op1l2, op1l3, op2l1.x, op2l1.y, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z);
  mul448round_v3(op1l0, op1l1, op1l2, op1l3, op2l1.y, op2l1.z, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w);
  mul448round_v3(op1l0, op1l1, op1l2, op1l3, op2l1.z, op2l1.w, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x);
  mul448round_v3(op1l0, op1l1, op1l2, op1l3, op2l1.w, op2l2.x, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y);
  mul448round_v3(op1l0, op1l1, op1l2, op1l3, op2l2.x, op2l2.y, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y, &R5z);
  mul448round_v3(op1l0, op1l1, op1l2, op1l3, op2l2.y, op2l2.z, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y, &R5z, &R5w);
  mul448round_v3(op1l0, op1l1, op1l2, op1l3, op2l2.z, op2l2.w, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y, &R5z, &R5w, &R6x);
  mul448round_v3(op1l0, op1l1, op1l2, op1l3, op2l2.w, op2l3.x, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y, &R5z, &R5w, &R6x, &R6y);
  mul448round_v3(op1l0, op1l1, op1l2, op1l3, op2l3.x, op2l3.y, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y, &R5z, &R5w, &R6x, &R6y, &R6z);

  union {
    uint2 v32;
    ulong v64;
  } Int;

  Int.v64 = R3z; R3w += Int.v32.y;
  Int.v64 = R3w; R4x += Int.v32.y;
  Int.v64 = R4x; R4y += Int.v32.y;
  Int.v64 = R4y; R4z += Int.v32.y;
  Int.v64 = R4z; R4w += Int.v32.y;
  Int.v64 = R4w; R5x += Int.v32.y;
  Int.v64 = R5x; R5y += Int.v32.y;
  Int.v64 = R5y; R5z += Int.v32.y;
  Int.v64 = R5z; R5w += Int.v32.y;
  Int.v64 = R5w; R6x += Int.v32.y;
  Int.v64 = R6x; R6y += Int.v32.y;
  Int.v64 = R6y; R6z += Int.v32.y;
  Int.v64 = R6z; R6w += Int.v32.y;

  *rl0 = (uint4){R0x, R0y, R0z, R0w};
  *rl1 = (uint4){R1x, R1y, R1z, R1w};
  *rl2 = (uint4){R2x, R2y, R2z, R2w};
  *rl3 = (uint4){R3x, R3y, R3z, R3w};
  *rl4 = (uint4){R4x, R4y, R4z, R4w};
  *rl5 = (uint4){R5x, R5y, R5z, R5w};
  *rl6 = (uint4){R6x, R6y, R6z, R6w};
# 849 "/tmp/comgr-7f7e55/input/CompileSource"
}


void mul512schoolBook_v3(uint4 op1l0, uint4 op1l1, uint4 op1l2, uint4 op1l3,
                         uint4 op2l0, uint4 op2l1, uint4 op2l2, uint4 op2l3,
                         uint4 *rl0, uint4 *rl1, uint4 *rl2, uint4 *rl3, uint4 *rl4, uint4 *rl5, uint4 *rl6, uint4 *rl7)
{
}

__kernel void multiplyBenchmark128(__global uint32_t *m1,
                                   __global uint32_t *m2,
                                   __global uint32_t *out,
                                   unsigned elementsNum)
{
  __global uint4 *M1 = (__global uint4*)m1;
  __global uint4 *M2 = (__global uint4*)m2;
  __global uint4 *OUT = (__global uint4*)out;

  unsigned globalSize = get_global_size(0);
  for (unsigned i = get_global_id(0); i < elementsNum; i += globalSize) {
    uint4 op0l0 = M1[i];
    uint4 op1l0 = M2[i];
    uint4 ResultLimb1;
    uint4 ResultLimb2;

    for (unsigned repeatNum = 0; repeatNum < 512; repeatNum++) {
      mul128schoolBook_v3(op0l0, op1l0, &ResultLimb1, &ResultLimb2);
      op0l0 = ResultLimb1;
    }

    OUT[i*2] = ResultLimb1;
    OUT[i*2+1] = ResultLimb2;
  }
}

__kernel void multiplyBenchmark256(__global uint32_t *m1,
                                   __global uint32_t *m2,
                                   __global uint32_t *out,
                                   unsigned elementsNum)
{
  __global uint4 *M1 = (__global uint4*)m1;
  __global uint4 *M2 = (__global uint4*)m2;
  __global uint4 *OUT = (__global uint4*)out;

  unsigned globalSize = get_global_size(0);
  for (unsigned i = get_global_id(0); i < elementsNum; i += globalSize) {
    uint4 op1l0 = M1[i*2];
    uint4 op1l1 = M1[i*2+1];
    uint4 op2l0 = M2[i*2];
    uint4 op2l1 = M2[i*2+1];
    uint4 ResultLimb1;
    uint4 ResultLimb2;
    uint4 ResultLimb3;
    uint4 ResultLimb4;

    for (unsigned repeatNum = 0; repeatNum < 512; repeatNum++) {
      mul256schoolBook_v3(op1l0, op1l1, op2l0, op2l1,
                          &ResultLimb1, &ResultLimb2, &ResultLimb3, &ResultLimb4);
      op1l0 = ResultLimb1;
      op1l1 = ResultLimb2;
    }

    OUT[i*4] = ResultLimb1;
    OUT[i*4+1] = ResultLimb2;
    OUT[i*4+2] = ResultLimb3;
    OUT[i*4+3] = ResultLimb4;
  }
}

__kernel void multiplyBenchmark384(__global uint32_t *m1,
                                   __global uint32_t *m2,
                                   __global uint32_t *out,
                                   unsigned elementsNum)
{
  __global uint4 *M1 = (__global uint4*)m1;
  __global uint4 *M2 = (__global uint4*)m2;
  __global uint4 *OUT = (__global uint4*)out;

  unsigned globalSize = get_global_size(0);
  for (unsigned i = get_global_id(0); i < elementsNum; i += globalSize) {
    uint4 op1l0 = M1[i*3];
    uint4 op1l1 = M1[i*3+1];
    uint4 op1l2 = M1[i*3+2];
    uint4 op2l0 = M2[i*3];
    uint4 op2l1 = M2[i*3+1];
    uint4 op2l2 = M2[i*3+2];
    uint4 ResultLimb1;
    uint4 ResultLimb2;
    uint4 ResultLimb3;
    uint4 ResultLimb4;
    uint4 ResultLimb5;
    uint4 ResultLimb6;

    for (unsigned repeatNum = 0; repeatNum < 512; repeatNum++) {
      mul384schoolBook_v3(op1l0, op1l1, op1l2, op2l0, op2l1, op2l2,
                          &ResultLimb1, &ResultLimb2, &ResultLimb3, &ResultLimb4, &ResultLimb5, &ResultLimb6);
      op1l0 = ResultLimb1;
      op1l1 = ResultLimb2;
      op1l2 = ResultLimb3;
    }

    OUT[i*6] = ResultLimb1;
    OUT[i*6+1] = ResultLimb2;
    OUT[i*6+2] = ResultLimb3;
    OUT[i*6+3] = ResultLimb4;
    OUT[i*6+4] = ResultLimb5;
    OUT[i*6+5] = ResultLimb6;
  }
}


__kernel void multiplyBenchmark448(__global uint32_t *m1,
                                   __global uint32_t *m2,
                                   __global uint32_t *out,
                                   unsigned elementsNum)
{
  __global uint4 *M1 = (__global uint4*)m1;
  __global uint4 *M2 = (__global uint4*)m2;
  __global uint4 *OUT = (__global uint4*)out;

  unsigned globalSize = get_global_size(0);
  for (unsigned i = get_global_id(0); i < elementsNum; i += globalSize) {
    uint4 op1l0 = *(__global uint4*)(m1 + i*14);
    uint4 op1l1 = *(__global uint4*)(m1 + i*14 + 4);
    uint4 op1l2 = *(__global uint4*)(m1 + i*14 + 8);
    uint2 op1l3 = *(__global uint2*)(m1 + i*14 + 12);
    uint4 op2l0 = *(__global uint4*)(m2 + i*14);
    uint4 op2l1 = *(__global uint4*)(m2 + i*14 + 4);
    uint4 op2l2 = *(__global uint4*)(m2 + i*14 + 8);
    uint2 op2l3 = *(__global uint2*)(m2 + i*14 + 12);
    uint4 ResultLimb1;
    uint4 ResultLimb2;
    uint4 ResultLimb3;
    uint4 ResultLimb4;
    uint4 ResultLimb5;
    uint4 ResultLimb6;
    uint4 ResultLimb7;

    for (unsigned repeatNum = 0; repeatNum < 512; repeatNum++) {
      mul448schoolBook_v3(op1l0, op1l1, op1l2, op1l3, op2l0, op2l1, op2l2, op2l3,
                          &ResultLimb1, &ResultLimb2, &ResultLimb3, &ResultLimb4, &ResultLimb5, &ResultLimb6, &ResultLimb7);
      op1l0 = ResultLimb1;
      op1l1 = ResultLimb2;
      op1l2 = ResultLimb3;
      op1l3 = ResultLimb4.xy;
    }

    OUT[i*7] = ResultLimb1;
    OUT[i*7+1] = ResultLimb2;
    OUT[i*7+2] = ResultLimb3;
    OUT[i*7+3] = ResultLimb4;
    OUT[i*7+4] = ResultLimb5;
    OUT[i*7+5] = ResultLimb6;
    OUT[i*7+6] = ResultLimb7;
  }
}


__kernel void multiplyBenchmark512(__global uint32_t *m1,
                                   __global uint32_t *m2,
                                   __global uint32_t *out,
                                   unsigned elementsNum)
{
  __global uint4 *M1 = (__global uint4*)m1;
  __global uint4 *M2 = (__global uint4*)m2;
  __global uint4 *OUT = (__global uint4*)out;

  unsigned globalSize = get_global_size(0);
  for (unsigned i = get_global_id(0); i < elementsNum; i += globalSize) {
    uint4 op1l0 = M1[i*4];
    uint4 op1l1 = M1[i*4+1];
    uint4 op1l2 = M1[i*4+2];
    uint4 op1l3 = M1[i*4+3];
    uint4 op2l0 = M2[i*4];
    uint4 op2l1 = M2[i*4+1];
    uint4 op2l2 = M2[i*4+2];
    uint4 op2l3 = M2[i*4+3];
    uint4 ResultLimb1;
    uint4 ResultLimb2;
    uint4 ResultLimb3;
    uint4 ResultLimb4;
    uint4 ResultLimb5;
    uint4 ResultLimb6;
    uint4 ResultLimb7;
    uint4 ResultLimb8;

    for (unsigned repeatNum = 0; repeatNum < 512; repeatNum++) {
      mul512schoolBook_v3(op1l0, op1l1, op1l2, op1l3, op2l0, op2l1, op2l2, op2l3,
                          &ResultLimb1, &ResultLimb2, &ResultLimb3, &ResultLimb4, &ResultLimb5, &ResultLimb6, &ResultLimb7, &ResultLimb8);
      op1l0 = ResultLimb1;
      op1l1 = ResultLimb2;
      op1l2 = ResultLimb3;
      op1l3 = ResultLimb4;
    }

    OUT[i*8] = ResultLimb1;
    OUT[i*8+1] = ResultLimb2;
    OUT[i*8+2] = ResultLimb3;
    OUT[i*8+3] = ResultLimb4;
    OUT[i*8+4] = ResultLimb5;
    OUT[i*8+5] = ResultLimb6;
    OUT[i*8+6] = ResultLimb7;
    OUT[i*8+7] = ResultLimb8;
  }
}

void lshiftByLimb2(uint4 *limbs1,
                   uint4 *limbs2)
{
  (*limbs2).yzw = (*limbs2).xyz; (*limbs2).x = (*limbs1).w;
  (*limbs1).yzw = (*limbs1).xyz; (*limbs1).x = 0;
}

void rshiftByLimb2(uint4 *limbs1,
                   uint4 *limbs2)
{
  (*limbs1).xyz = (*limbs1).yzw; (*limbs1).w = (*limbs2).x;
  (*limbs2).xyz = (*limbs2).yzw; (*limbs2).w = 0;
}

void lshiftByLimb3(uint4 *limbs1,
                   uint4 *limbs2,
                   uint4 *limbs3)
{
  (*limbs3).yzw = (*limbs3).xyz; (*limbs3).x = (*limbs2).w;
  (*limbs2).yzw = (*limbs2).xyz; (*limbs2).x = (*limbs1).w;
  (*limbs1).yzw = (*limbs1).xyz; (*limbs1).x = 0;
}

void rshiftByLimb3(uint4 *limbs1,
                   uint4 *limbs2,
                   uint4 *limbs3)
{
  (*limbs1).xyz = (*limbs1).yzw; (*limbs1).w = (*limbs2).x;
  (*limbs2).xyz = (*limbs2).yzw; (*limbs2).w = (*limbs3).x;
  (*limbs3).xyz = (*limbs3).yzw; (*limbs3).w = 0;
}

void lshiftByLimb4(uint4 *limbs1,
                   uint4 *limbs2,
                   uint4 *limbs3,
                   uint4 *limbs4)
{
  (*limbs4).yzw = (*limbs4).xyz; (*limbs4).x = (*limbs3).w;
  (*limbs3).yzw = (*limbs3).xyz; (*limbs3).x = (*limbs2).w;
  (*limbs2).yzw = (*limbs2).xyz; (*limbs2).x = (*limbs1).w;
  (*limbs1).yzw = (*limbs1).xyz; (*limbs1).x = 0;
}

void rshiftByLimb4(uint4 *limbs1,
                   uint4 *limbs2,
                   uint4 *limbs3,
                   uint4 *limbs4)
{
  (*limbs1).xyz = (*limbs1).yzw; (*limbs1).w = (*limbs2).x;
  (*limbs2).xyz = (*limbs2).yzw; (*limbs2).w = (*limbs3).x;
  (*limbs3).xyz = (*limbs3).yzw; (*limbs3).w = (*limbs4).x;
  (*limbs4).xyz = (*limbs4).yzw; (*limbs4).w = 0;
}

void lshiftByLimb5(uint4 *limbs1,
                   uint4 *limbs2,
                   uint4 *limbs3,
                   uint4 *limbs4,
                   uint4 *limbs5)
{
  (*limbs5).yzw = (*limbs5).xyz; (*limbs5).x = (*limbs4).w;
  (*limbs4).yzw = (*limbs4).xyz; (*limbs4).x = (*limbs3).w;
  (*limbs3).yzw = (*limbs3).xyz; (*limbs3).x = (*limbs2).w;
  (*limbs2).yzw = (*limbs2).xyz; (*limbs2).x = (*limbs1).w;
  (*limbs1).yzw = (*limbs1).xyz; (*limbs1).x = 0;
}

void rshiftByLimb5(uint4 *limbs1,
                   uint4 *limbs2,
                   uint4 *limbs3,
                   uint4 *limbs4,
                   uint4 *limbs5)
{
  (*limbs1).xyz = (*limbs1).yzw; (*limbs1).w = (*limbs2).x;
  (*limbs2).xyz = (*limbs2).yzw; (*limbs2).w = (*limbs3).x;
  (*limbs3).xyz = (*limbs3).yzw; (*limbs3).w = (*limbs4).x;
  (*limbs4).xyz = (*limbs4).yzw; (*limbs4).w = (*limbs5).x;
  (*limbs5).xyz = (*limbs5).yzw; (*limbs5).w = 0;
}

void rshiftByLimb6(uint4 *limbs1,
                   uint4 *limbs2,
                   uint4 *limbs3,
                   uint4 *limbs4,
                   uint4 *limbs5,
                   uint4 *limbs6)
{
  (*limbs1).xyz = (*limbs1).yzw; (*limbs1).w = (*limbs2).x;
  (*limbs2).xyz = (*limbs2).yzw; (*limbs2).w = (*limbs3).x;
  (*limbs3).xyz = (*limbs3).yzw; (*limbs3).w = (*limbs4).x;
  (*limbs4).xyz = (*limbs4).yzw; (*limbs4).w = (*limbs5).x;
  (*limbs5).xyz = (*limbs5).yzw; (*limbs5).w = (*limbs6).x;
  (*limbs6).xyz = (*limbs6).yzw; (*limbs6).w = 0;
}

void lshift2(uint4 *limbs1, uint4 *limbs2, unsigned count)
{
  if (!count)
    return;
  unsigned lowBitsCount = 32 - count;

  {
    uint4 lowBits = {
      (*limbs1).w >> lowBitsCount,
      (*limbs2).x >> lowBitsCount,
      (*limbs2).y >> lowBitsCount,
      (*limbs2).z >> lowBitsCount
    };
    (*limbs2) = ((*limbs2) << count) | lowBits;
  }

  {
    uint4 lowBits = {
      0,
      (*limbs1).x >> lowBitsCount,
      (*limbs1).y >> lowBitsCount,
      (*limbs1).z >> lowBitsCount
    };
    (*limbs1) = ((*limbs1) << count) | lowBits;
  }
}

void rshift2(uint4 *limbs1, uint4 *limbs2, unsigned count)
{
  if (!count)
    return;
  unsigned lowBitsCount = 32 - count;

  {
    uint4 lowBits = {
      (*limbs1).y << lowBitsCount,
      (*limbs1).z << lowBitsCount,
      (*limbs1).w << lowBitsCount,
      (*limbs2).x << lowBitsCount
    };
    (*limbs1) = ((*limbs1) >> count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs2).y << lowBitsCount,
      (*limbs2).z << lowBitsCount,
      (*limbs2).w << lowBitsCount,
      0
    };
    (*limbs2) = ((*limbs2) >> count) | lowBits;
  }
}

void lshift3(uint4 *limbs1, uint4 *limbs2, uint4 *limbs3, unsigned count)
{
  if (!count)
    return;
  unsigned lowBitsCount = 32 - count;

  {
    uint4 lowBits = {
      (*limbs2).w >> lowBitsCount,
      (*limbs3).x >> lowBitsCount,
      (*limbs3).y >> lowBitsCount,
      (*limbs3).z >> lowBitsCount
    };
    (*limbs3) = ((*limbs3) << count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs1).w >> lowBitsCount,
      (*limbs2).x >> lowBitsCount,
      (*limbs2).y >> lowBitsCount,
      (*limbs2).z >> lowBitsCount
    };
    (*limbs2) = ((*limbs2) << count) | lowBits;
  }

  {
    uint4 lowBits = {
      0,
      (*limbs1).x >> lowBitsCount,
      (*limbs1).y >> lowBitsCount,
      (*limbs1).z >> lowBitsCount
    };
    (*limbs1) = ((*limbs1) << count) | lowBits;
  }
}

void rshift3(uint4 *limbs1, uint4 *limbs2, uint4 *limbs3, unsigned count)
{
  if (!count)
    return;
  unsigned lowBitsCount = 32 - count;

  {
    uint4 lowBits = {
      (*limbs1).y << lowBitsCount,
      (*limbs1).z << lowBitsCount,
      (*limbs1).w << lowBitsCount,
      (*limbs2).x << lowBitsCount
    };
    (*limbs1) = ((*limbs1) >> count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs2).y << lowBitsCount,
      (*limbs2).z << lowBitsCount,
      (*limbs2).w << lowBitsCount,
      (*limbs3).x << lowBitsCount
    };
    (*limbs2) = ((*limbs2) >> count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs3).y << lowBitsCount,
      (*limbs3).z << lowBitsCount,
      (*limbs3).w << lowBitsCount,
      0
    };
    (*limbs3) = ((*limbs3) >> count) | lowBits;
  }
}

void lshift4(uint4 *limbs1, uint4 *limbs2, uint4 *limbs3, uint4 *limbs4, unsigned count)
{
  if (!count)
    return;
  unsigned lowBitsCount = 32 - count;

  {
    uint4 lowBits = {
      (*limbs3).w >> lowBitsCount,
      (*limbs4).x >> lowBitsCount,
      (*limbs4).y >> lowBitsCount,
      (*limbs4).z >> lowBitsCount
    };
    (*limbs4) = ((*limbs4) << count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs2).w >> lowBitsCount,
      (*limbs3).x >> lowBitsCount,
      (*limbs3).y >> lowBitsCount,
      (*limbs3).z >> lowBitsCount
    };
    (*limbs3) = ((*limbs3) << count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs1).w >> lowBitsCount,
      (*limbs2).x >> lowBitsCount,
      (*limbs2).y >> lowBitsCount,
      (*limbs2).z >> lowBitsCount
    };
    (*limbs2) = ((*limbs2) << count) | lowBits;
  }

  {
    uint4 lowBits = {
      0,
      (*limbs1).x >> lowBitsCount,
      (*limbs1).y >> lowBitsCount,
      (*limbs1).z >> lowBitsCount
    };
    (*limbs1) = ((*limbs1) << count) | lowBits;
  }
}

void lshift5(uint4 *limbs1, uint4 *limbs2, uint4 *limbs3, uint4 *limbs4, uint4 *limbs5, unsigned count)
{
  if (!count)
    return;
  unsigned lowBitsCount = 32 - count;

  {
    uint4 lowBits = {
      (*limbs4).w >> lowBitsCount,
      (*limbs5).x >> lowBitsCount,
      (*limbs5).y >> lowBitsCount,
      (*limbs5).z >> lowBitsCount
    };
    (*limbs5) = ((*limbs5) << count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs3).w >> lowBitsCount,
      (*limbs4).x >> lowBitsCount,
      (*limbs4).y >> lowBitsCount,
      (*limbs4).z >> lowBitsCount
    };
    (*limbs4) = ((*limbs4) << count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs2).w >> lowBitsCount,
      (*limbs3).x >> lowBitsCount,
      (*limbs3).y >> lowBitsCount,
      (*limbs3).z >> lowBitsCount
    };
    (*limbs3) = ((*limbs3) << count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs1).w >> lowBitsCount,
      (*limbs2).x >> lowBitsCount,
      (*limbs2).y >> lowBitsCount,
      (*limbs2).z >> lowBitsCount
    };
    (*limbs2) = ((*limbs2) << count) | lowBits;
  }

  {
    uint4 lowBits = {
      0,
      (*limbs1).x >> lowBitsCount,
      (*limbs1).y >> lowBitsCount,
      (*limbs1).z >> lowBitsCount
    };
    (*limbs1) = ((*limbs1) << count) | lowBits;
  }
}


void rshift4(uint4 *limbs1, uint4 *limbs2, uint4 *limbs3, uint4 *limbs4, unsigned count)
{
  if (!count)
    return;
  unsigned lowBitsCount = 32 - count;

  {
    uint4 lowBits = {
      (*limbs1).y << lowBitsCount,
      (*limbs1).z << lowBitsCount,
      (*limbs1).w << lowBitsCount,
      (*limbs2).x << lowBitsCount
    };
    (*limbs1) = ((*limbs1) >> count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs2).y << lowBitsCount,
      (*limbs2).z << lowBitsCount,
      (*limbs2).w << lowBitsCount,
      (*limbs3).x << lowBitsCount
    };
    (*limbs2) = ((*limbs2) >> count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs3).y << lowBitsCount,
      (*limbs3).z << lowBitsCount,
      (*limbs3).w << lowBitsCount,
      (*limbs4).x << lowBitsCount,
    };
    (*limbs3) = ((*limbs3) >> count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs4).y << lowBitsCount,
      (*limbs4).z << lowBitsCount,
      (*limbs4).w << lowBitsCount,
      0
    };
    (*limbs4) = ((*limbs4) >> count) | lowBits;
  }
}


void rshift5(uint4 *limbs1, uint4 *limbs2, uint4 *limbs3, uint4 *limbs4, uint4 *limbs5, unsigned count)
{
  if (!count)
    return;
  unsigned lowBitsCount = 32 - count;

  {
    uint4 lowBits = {
      (*limbs1).y << lowBitsCount,
      (*limbs1).z << lowBitsCount,
      (*limbs1).w << lowBitsCount,
      (*limbs2).x << lowBitsCount
    };
    (*limbs1) = ((*limbs1) >> count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs2).y << lowBitsCount,
      (*limbs2).z << lowBitsCount,
      (*limbs2).w << lowBitsCount,
      (*limbs3).x << lowBitsCount
    };
    (*limbs2) = ((*limbs2) >> count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs3).y << lowBitsCount,
      (*limbs3).z << lowBitsCount,
      (*limbs3).w << lowBitsCount,
      (*limbs4).x << lowBitsCount,
    };
    (*limbs3) = ((*limbs3) >> count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs4).y << lowBitsCount,
      (*limbs4).z << lowBitsCount,
      (*limbs4).w << lowBitsCount,
      (*limbs5).x << lowBitsCount,
    };
    (*limbs4) = ((*limbs4) >> count) | lowBits;
  }

  {
    uint4 lowBits = {
      (*limbs5).y << lowBitsCount,
      (*limbs5).z << lowBitsCount,
      (*limbs5).w << lowBitsCount,
      0
    };
    (*limbs5) = ((*limbs5) >> count) | lowBits;
  }
}



void subMul1_v2(uint4 *b0, uint4 *b1, uint4 *b2,
                uint4 a0, uint4 a1,
                uint32_t M)
{


  uint4 Mv4 = {M, M, M, M};
  uint32_t clow;
  uint4 c1 = {0, 0, 0, 0};
  uint4 c2 = {0, 0, 0, 0};

  {
    uint4 a0M = a0*Mv4;
    uint4 a0Mhi = mul_hi(a0, Mv4);

    clow = (*b0).w < a0M.x;
    (*b0).w -= a0M.x;

    c1.xyz -= convert_uint3((*b1).xyz < a0M.yzw);
    (*b1).xyz -= a0M.yzw;

    c1 -= convert_uint4((*b1) < a0Mhi);
    (*b1) -= a0Mhi;
  }

  {
    uint4 a1M = a1*Mv4;
    uint4 a1Mhi = mul_hi(a1, Mv4);

    c1.w += ((*b1).w < a1M.x);
    (*b1).w -= a1M.x;

    c2.xyz -= convert_uint3((*b2).xyz < a1M.yzw);
    (*b2).xyz -= a1M.yzw;

    c2 -= convert_uint4((*b2) < a1Mhi);
    (*b2) -= a1Mhi;
  }

  c1.x += ((*b1).x < clow); (*b1).x -= clow;;
  c1.y += ((*b1).y < c1.x); (*b1).y -= c1.x;;
  c1.z += ((*b1).z < c1.y); (*b1).z -= c1.y;;
  c1.w += ((*b1).w < c1.z); (*b1).w -= c1.z;;
  c2.x += ((*b2).x < c1.w); (*b2).x -= c1.w;;
  c2.y += ((*b2).y < c2.x); (*b2).y -= c2.x;;
  c2.z += ((*b2).z < c2.y); (*b2).z -= c2.y;;
  c2.w += ((*b2).w < c2.z); (*b2).w -= c2.z;;

}


void subMul1_v3(uint4 *b0, uint4 *b1, uint4 *b2, uint4 *b3,
                uint4 a0, uint4 a1, uint4 a2,
                uint32_t M)
{


  uint4 Mv4 = {M, M, M, M};
  uint32_t clow;
  uint4 c1 = {0, 0, 0, 0};
  uint4 c2 = {0, 0, 0, 0};
  uint4 c3 = {0, 0, 0, 0};

  {
    uint4 a0M = a0*Mv4;
    uint4 a0Mhi = mul_hi(a0, Mv4);

    clow = (*b0).w < a0M.x;
    (*b0).w -= a0M.x;

    c1.xyz -= convert_uint3((*b1).xyz < a0M.yzw);
    (*b1).xyz -= a0M.yzw;

    c1 -= convert_uint4((*b1) < a0Mhi);
    (*b1) -= a0Mhi;
  }

  {
    uint4 a1M = a1*Mv4;
    uint4 a1Mhi = mul_hi(a1, Mv4);

    c1.w += ((*b1).w < a1M.x);
    (*b1).w -= a1M.x;

    c2.xyz -= convert_uint3((*b2).xyz < a1M.yzw);
    (*b2).xyz -= a1M.yzw;

    c2 -= convert_uint4((*b2) < a1Mhi);
    (*b2) -= a1Mhi;
  }

  {
    uint4 a2M = a2*Mv4;
    uint4 a2Mhi = mul_hi(a2, Mv4);

    c2.w += ((*b2).w < a2M.x);
    (*b2).w -= a2M.x;

    c3.xyz -= convert_uint3((*b3).xyz < a2M.yzw);
    (*b3).xyz -= a2M.yzw;
    c3 -= convert_uint4((*b3) < a2Mhi);
    (*b3) -= a2Mhi;
  }

  c1.x += ((*b1).x < clow); (*b1).x -= clow;;
  c1.y += ((*b1).y < c1.x); (*b1).y -= c1.x;;
  c1.z += ((*b1).z < c1.y); (*b1).z -= c1.y;;
  c1.w += ((*b1).w < c1.z); (*b1).w -= c1.z;;
  c2.x += ((*b2).x < c1.w); (*b2).x -= c1.w;;
  c2.y += ((*b2).y < c2.x); (*b2).y -= c2.x;;
  c2.z += ((*b2).z < c2.y); (*b2).z -= c2.y;;
  c2.w += ((*b2).w < c2.z); (*b2).w -= c2.z;;
  c3.x += ((*b3).x < c2.w); (*b3).x -= c2.w;;
  c3.y += ((*b3).y < c3.x); (*b3).y -= c3.x;;
  c3.z += ((*b3).z < c3.y); (*b3).z -= c3.y;;
  c3.w += ((*b3).w < c3.z); (*b3).w -= c3.z;;

}


void subMul1_512(uint4 *b0, uint4 *b1, uint4 *b2, uint4 *b3, uint4 *b4,
                uint4 a0, uint4 a1, uint4 a2, uint4 a3,
                uint32_t M)
{


  uint4 Mv4 = {M, M, M, M};
  uint32_t clow;
  uint4 c1 = {0, 0, 0, 0};
  uint4 c2 = {0, 0, 0, 0};
  uint4 c3 = {0, 0, 0, 0};
  uint4 c4 = {0, 0, 0, 0};

  {
    uint4 a0M = a0*Mv4;
    uint4 a0Mhi = mul_hi(a0, Mv4);

    clow = (*b0).w < a0M.x;
    (*b0).w -= a0M.x;

    c1.xyz -= convert_uint3((*b1).xyz < a0M.yzw);
    (*b1).xyz -= a0M.yzw;

    c1 -= convert_uint4((*b1) < a0Mhi);
    (*b1) -= a0Mhi;
  }

  {
    uint4 a1M = a1*Mv4;
    uint4 a1Mhi = mul_hi(a1, Mv4);

    c1.w += ((*b1).w < a1M.x);
    (*b1).w -= a1M.x;

    c2.xyz -= convert_uint3((*b2).xyz < a1M.yzw);
    (*b2).xyz -= a1M.yzw;

    c2 -= convert_uint4((*b2) < a1Mhi);
    (*b2) -= a1Mhi;
  }

  {
    uint4 a2M = a2*Mv4;
    uint4 a2Mhi = mul_hi(a2, Mv4);

    c2.w += ((*b2).w < a2M.x);
    (*b2).w -= a2M.x;

    c3.xyz -= convert_uint3((*b3).xyz < a2M.yzw);
    (*b3).xyz -= a2M.yzw;
    c3 -= convert_uint4((*b3) < a2Mhi);
    (*b3) -= a2Mhi;
  }

  {
    uint4 a3M = a3*Mv4;
    uint4 a3Mhi = mul_hi(a3, Mv4);

    c3.w += ((*b3).w < a3M.x);
    (*b3).w -= a3M.x;

    c4.xyz -= convert_uint3((*b4).xyz < a3M.yzw);
    (*b4).xyz -= a3M.yzw;
    c4 -= convert_uint4((*b4) < a3Mhi);
    (*b4) -= a3Mhi;
  }

  c1.x += ((*b1).x < clow); (*b1).x -= clow;;
  c1.y += ((*b1).y < c1.x); (*b1).y -= c1.x;;
  c1.z += ((*b1).z < c1.y); (*b1).z -= c1.y;;
  c1.w += ((*b1).w < c1.z); (*b1).w -= c1.z;;
  c2.x += ((*b2).x < c1.w); (*b2).x -= c1.w;;
  c2.y += ((*b2).y < c2.x); (*b2).y -= c2.x;;
  c2.z += ((*b2).z < c2.y); (*b2).z -= c2.y;;
  c2.w += ((*b2).w < c2.z); (*b2).w -= c2.z;;
  c3.x += ((*b3).x < c2.w); (*b3).x -= c2.w;;
  c3.y += ((*b3).y < c3.x); (*b3).y -= c3.x;;
  c3.z += ((*b3).z < c3.y); (*b3).z -= c3.y;;
  c3.w += ((*b3).w < c3.z); (*b3).w -= c3.z;;
  c4.x += ((*b4).x < c3.w); (*b4).x -= c3.w;;
  c4.y += ((*b4).y < c4.x); (*b4).y -= c4.x;;
  c4.z += ((*b4).z < c4.y); (*b4).z -= c4.y;;
  c4.w += ((*b4).w < c4.z); (*b4).w -= c4.z;;

}


uint2 modulo384to256(uint4 dividendLimbs0,
                     uint4 dividendLimbs1,
                     uint4 dividendLimbs2,
                     uint4 divisorLimbs0,
                     uint4 divisorLimbs1,
                     uint4 *moduloLimbs0,
                     uint4 *moduloLimbs1)
{

  unsigned dividendLimbs = 12;
  unsigned divisorLimbs = 8;

  while (divisorLimbs && !divisorLimbs1.w) {
    lshiftByLimb2(&divisorLimbs0, &divisorLimbs1);
    divisorLimbs--;
  }


  unsigned normalizeShiftCount = 0;
  uint32_t bit = 0x80000000;
  while (!(divisorLimbs1.w & bit)) {
    normalizeShiftCount++;
    bit >>= 1;
  }

  lshift3(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, normalizeShiftCount);
  lshift2(&divisorLimbs0, &divisorLimbs1, normalizeShiftCount);


  while (dividendLimbs && !dividendLimbs2.w) {
    lshiftByLimb3(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2);
    dividendLimbs--;
  }

  for (unsigned i = 0; i < (dividendLimbs - divisorLimbs); i++) {

    uint32_t i32quotient;
    if (dividendLimbs2.w == divisorLimbs1.w) {
      i32quotient = 0xFFFFFFFF;
    } else {
      uint64_t i64dividend = (((uint64_t)dividendLimbs2.w) << 32) | dividendLimbs2.z;
      i32quotient = i64dividend / divisorLimbs1.w;
    }

    subMul1_v2(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2,
               divisorLimbs0, divisorLimbs1,
               i32quotient);
    uint32_t borrow = dividendLimbs2.w;
    lshiftByLimb3(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2);
    if (borrow) {
      add256(&dividendLimbs1, &dividendLimbs2, divisorLimbs0, divisorLimbs1);
      if (dividendLimbs2.w > divisorLimbs1.w)
        add256(&dividendLimbs1, &dividendLimbs2, divisorLimbs0, divisorLimbs1);
    }
  }

  rshift3(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, normalizeShiftCount);
  for (unsigned i = 0; i < (8-divisorLimbs); i++)
    rshiftByLimb3(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2);

  *moduloLimbs0 = dividendLimbs1;
  *moduloLimbs1 = dividendLimbs2;
  return (uint2){divisorLimbs, 32-normalizeShiftCount};
}


uint2 modulo512to384(uint4 dividendLimbs0,
                     uint4 dividendLimbs1,
                     uint4 dividendLimbs2,
                     uint4 dividendLimbs3,
                     uint4 divisorLimbs0,
                     uint4 divisorLimbs1,
                     uint4 divisorLimbs2,
                     uint4 *moduloLimbs0,
                     uint4 *moduloLimbs1,
                     uint4 *moduloLimbs2)
{

  unsigned dividendLimbs = 16;
  unsigned divisorLimbs = 12;

  while (divisorLimbs && !divisorLimbs2.w) {
    lshiftByLimb3(&divisorLimbs0, &divisorLimbs1, &divisorLimbs2);
    divisorLimbs--;
  }


  unsigned normalizeShiftCount = 0;
  uint32_t bit = 0x80000000;
  while (!(divisorLimbs2.w & bit)) {
    normalizeShiftCount++;
    bit >>= 1;
  }

  lshift4(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, &dividendLimbs3, normalizeShiftCount);
  lshift3(&divisorLimbs0, &divisorLimbs1, &divisorLimbs2, normalizeShiftCount);


  while (dividendLimbs && !dividendLimbs3.w) {
    lshiftByLimb4(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, &dividendLimbs3);
    dividendLimbs--;
  }

  for (unsigned i = 0; i < (dividendLimbs - divisorLimbs); i++) {
    uint32_t i32quotient;
    if (dividendLimbs3.w == divisorLimbs2.w) {
      i32quotient = 0xFFFFFFFF;
    } else {
      uint64_t i64dividend = (((uint64_t)dividendLimbs3.w) << 32) | dividendLimbs3.z;
      i32quotient = i64dividend / divisorLimbs2.w;
    }

    subMul1_v3(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, &dividendLimbs3,
               divisorLimbs0, divisorLimbs1, divisorLimbs2,
               i32quotient);
    uint32_t borrow = dividendLimbs3.w;
    lshiftByLimb4(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, &dividendLimbs3);
    if (borrow) {
      add384(&dividendLimbs1, &dividendLimbs2, &dividendLimbs3, divisorLimbs0, divisorLimbs1, divisorLimbs2);
      if (dividendLimbs3.w > divisorLimbs2.w)
        add384(&dividendLimbs1, &dividendLimbs2, &dividendLimbs3, divisorLimbs0, divisorLimbs1, divisorLimbs2);
    }
  }

  rshift4(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, &dividendLimbs3, normalizeShiftCount);
  for (unsigned i = 0; i < (12-divisorLimbs); i++)
    rshiftByLimb4(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, &dividendLimbs3);

  *moduloLimbs0 = dividendLimbs1;
  *moduloLimbs1 = dividendLimbs2;
  *moduloLimbs2 = dividendLimbs3;
  return (uint2){divisorLimbs, 32-normalizeShiftCount};
}


uint2 modulo640to512(uint4 dividendLimbs0,
                     uint4 dividendLimbs1,
                     uint4 dividendLimbs2,
                     uint4 dividendLimbs3,
                     uint4 dividendLimbs4,
                     uint4 divisorLimbs0,
                     uint4 divisorLimbs1,
                     uint4 divisorLimbs2,
                     uint4 divisorLimbs3,
                     uint4 *moduloLimbs0,
                     uint4 *moduloLimbs1,
                     uint4 *moduloLimbs2,
                     uint4 *moduloLimbs3)
{

  unsigned dividendLimbs = 20;
  unsigned divisorLimbs = 16;

  while (divisorLimbs && !divisorLimbs3.w) {
    lshiftByLimb4(&divisorLimbs0, &divisorLimbs1, &divisorLimbs2, &divisorLimbs3);
    divisorLimbs--;
  }


  unsigned normalizeShiftCount = 0;
  uint32_t bit = 0x80000000;
  while (!(divisorLimbs3.w & bit)) {
    normalizeShiftCount++;
    bit >>= 1;
  }

  lshift5(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, &dividendLimbs3, &dividendLimbs4, normalizeShiftCount);
  lshift4(&divisorLimbs0, &divisorLimbs1, &divisorLimbs2, &divisorLimbs3, normalizeShiftCount);


  while (dividendLimbs && !dividendLimbs4.w) {
    lshiftByLimb5(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, &dividendLimbs3, &dividendLimbs4);
    dividendLimbs--;
  }

  for (unsigned i = 0; i < (dividendLimbs - divisorLimbs); i++) {
    uint32_t i32quotient;
    if (dividendLimbs4.w == divisorLimbs3.w) {
      i32quotient = 0xFFFFFFFF;
    } else {
      uint64_t i64dividend = (((uint64_t)dividendLimbs4.w) << 32) | dividendLimbs4.z;
      i32quotient = i64dividend / divisorLimbs3.w;
    }

    subMul1_512(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, &dividendLimbs3, &dividendLimbs4,
                 divisorLimbs0, divisorLimbs1, divisorLimbs2, divisorLimbs3,
                 i32quotient);
    uint32_t borrow = dividendLimbs4.w;
    lshiftByLimb5(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, &dividendLimbs3, &dividendLimbs4);
    if (borrow) {
      add512(&dividendLimbs1, &dividendLimbs2, &dividendLimbs3, &dividendLimbs4, divisorLimbs0, divisorLimbs1, divisorLimbs2, divisorLimbs3);
      if (dividendLimbs4.w > divisorLimbs3.w)
        add512(&dividendLimbs1, &dividendLimbs2, &dividendLimbs3, &dividendLimbs4, divisorLimbs0, divisorLimbs1, divisorLimbs2, divisorLimbs3);
    }
  }

  rshift5(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, &dividendLimbs3, &dividendLimbs4, normalizeShiftCount);
  for (unsigned i = 0; i < (16-divisorLimbs); i++)
    rshiftByLimb5(&dividendLimbs0, &dividendLimbs1, &dividendLimbs2, &dividendLimbs3, &dividendLimbs4);

  *moduloLimbs0 = dividendLimbs1;
  *moduloLimbs1 = dividendLimbs2;
  *moduloLimbs2 = dividendLimbs3;
  *moduloLimbs3 = dividendLimbs4;
  return (uint2){divisorLimbs, 32-normalizeShiftCount};
}


uint32_t invert_limb(uint32_t limb)
{
  uint32_t inv = binvert_limb_table[(limb/2) & 0x7F];
  inv = 2*inv - inv*inv*limb;
  inv = 2*inv - inv*inv*limb;
  return -inv;
}

void redc256_round_v3(uint4 op1l0, uint4 op1l1, uint32_t m1, uint32_t *m2, uint32_t invm,
                      uint64_t *R0, uint64_t *R1, uint64_t *R2, uint64_t *R3,
                      uint64_t *R4, uint64_t *R5, uint64_t *R6, uint64_t *R7)
{
  uint4 m1l0 = mul_hi(op1l0, m1);
  uint4 m1l1 = mul_hi(op1l1, m1);

  *m2 = invm * ((uint32_t)*R0 + m1l0.x);
  uint4 m2l0 = op1l0 * (*m2);
  uint4 m2l1 = op1l1 * (*m2);

  union {
    uint2 v32;
    ulong v64;
  } Int;

  *R0 += m1l0.x; *R0 += m2l0.x;
  *R1 += m1l0.y; *R1 += m2l0.y; Int.v64 = *R0; *R1 += Int.v32.y;
  *R2 += m1l0.z; *R2 += m2l0.z;
  *R3 += m1l0.w; *R3 += m2l0.w;
  *R4 += m1l1.x; *R4 += m2l1.x;
  *R5 += m1l1.y; *R5 += m2l1.y;
  *R6 += m1l1.z; *R6 += m2l1.z;
  *R7 += m1l1.w; *R7 += m2l1.w;
}


void redc384_round_v3(uint4 op1l0, uint4 op1l1, uint4 op1l2, uint32_t m1, uint32_t *m2, uint32_t invm,
                      uint64_t *R0, uint64_t *R1, uint64_t *R2, uint64_t *R3,
                      uint64_t *R4, uint64_t *R5, uint64_t *R6, uint64_t *R7,
                      uint64_t *R8, uint64_t *R9, uint64_t *R10, uint64_t *R11)
{
  uint4 m1l0 = mul_hi(op1l0, m1);
  uint4 m1l1 = mul_hi(op1l1, m1);
  uint4 m1l2 = mul_hi(op1l2, m1);

  *m2 = invm * ((uint32_t)*R0 + m1l0.x);
  uint4 m2l0 = op1l0 * (*m2);
  uint4 m2l1 = op1l1 * (*m2);
  uint4 m2l2 = op1l2 * (*m2);

  union {
    uint2 v32;
    ulong v64;
  } Int;

  *R0 += m1l0.x; *R0 += m2l0.x;
  *R1 += m1l0.y; *R1 += m2l0.y; Int.v64 = *R0; *R1 += Int.v32.y;
  *R2 += m1l0.z; *R2 += m2l0.z;
  *R3 += m1l0.w; *R3 += m2l0.w;
  *R4 += m1l1.x; *R4 += m2l1.x;
  *R5 += m1l1.y; *R5 += m2l1.y;
  *R6 += m1l1.z; *R6 += m2l1.z;
  *R7 += m1l1.w; *R7 += m2l1.w;
  *R8 += m1l2.x; *R8 += m2l2.x;
  *R9 += m1l2.y; *R9 += m2l2.y;
  *R10 += m1l2.z; *R10 += m2l2.z;
  *R11 += m1l2.w; *R11 += m2l2.w;
}


void redc448_round_v3(uint4 op1l0, uint4 op1l1, uint4 op1l2, uint2 op1l3, uint32_t m1, uint32_t *m2, uint32_t invm,
                      uint64_t *R0, uint64_t *R1, uint64_t *R2, uint64_t *R3,
                      uint64_t *R4, uint64_t *R5, uint64_t *R6, uint64_t *R7,
                      uint64_t *R8, uint64_t *R9, uint64_t *R10, uint64_t *R11,
                      uint64_t *R12, uint64_t *R13)
{
  uint4 m1l0 = mul_hi(op1l0, m1);
  uint4 m1l1 = mul_hi(op1l1, m1);
  uint4 m1l2 = mul_hi(op1l2, m1);
  uint2 m1l3 = mul_hi(op1l3, m1);

  *m2 = invm * ((uint32_t)*R0 + m1l0.x);
  uint4 m2l0 = op1l0 * (*m2);
  uint4 m2l1 = op1l1 * (*m2);
  uint4 m2l2 = op1l2 * (*m2);
  uint2 m2l3 = op1l3 * (*m2);

  union {
    uint2 v32;
    ulong v64;
  } Int;

  *R0 += m1l0.x; *R0 += m2l0.x;
  *R1 += m1l0.y; *R1 += m2l0.y; Int.v64 = *R0; *R1 += Int.v32.y;
  *R2 += m1l0.z; *R2 += m2l0.z;
  *R3 += m1l0.w; *R3 += m2l0.w;
  *R4 += m1l1.x; *R4 += m2l1.x;
  *R5 += m1l1.y; *R5 += m2l1.y;
  *R6 += m1l1.z; *R6 += m2l1.z;
  *R7 += m1l1.w; *R7 += m2l1.w;
  *R8 += m1l2.x; *R8 += m2l2.x;
  *R9 += m1l2.y; *R9 += m2l2.y;
  *R10 += m1l2.z; *R10 += m2l2.z;
  *R11 += m1l2.w; *R11 += m2l2.w;
  *R12 += m1l3.x; *R12 += m2l3.x;
  *R13 += m1l3.y; *R13 += m2l3.y;
}


void redc1_256_v3(uint4 limbs0, uint4 limbs1, uint4 limbs2, uint4 limbs3,
                  uint4 moduloLimb0, uint4 moduloLimb1,
                  uint32_t invm,
                  uint4 *ResultLimb0, uint4 *ResultLimb1)
{
  ulong R0x = limbs0.x;
  ulong R0y = limbs0.y;
  ulong R0z = limbs0.z;
  ulong R0w = limbs0.w;
  ulong R1x = limbs1.x;
  ulong R1y = limbs1.y;
  ulong R1z = limbs1.z;
  ulong R1w = limbs1.w;
  ulong R2x = limbs2.x;
  ulong R2y = limbs2.y;
  ulong R2z = limbs2.z;
  ulong R2w = limbs2.w;
  ulong R3x = limbs3.x;
  ulong R3y = limbs3.y;
  ulong R3z = limbs3.z;
  ulong R3w = limbs3.w;

  uint32_t i0, i1, i2, i3, i4, i5, i6, i7;
  union {
    uint2 v32;
    ulong v64;
  } Int;

  i0 = limbs0.x * invm;
  {
    uint4 M1l0 = moduloLimb0 * i0;
    uint4 M1l1 = moduloLimb1 * i0;
    R0x += M1l0.x;
    R0y += M1l0.y; Int.v64 = R0x; R0y += Int.v32.y;
    R0z += M1l0.z;
    R0w += M1l0.w;
    R1x += M1l1.x;
    R1y += M1l1.y;
    R1z += M1l1.z;
    R1w += M1l1.w;
  }

  redc256_round_v3(moduloLimb0, moduloLimb1, i0, &i1, invm, &R0y, &R0z, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x);
  redc256_round_v3(moduloLimb0, moduloLimb1, i1, &i2, invm, &R0z, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y);
  redc256_round_v3(moduloLimb0, moduloLimb1, i2, &i3, invm, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z);
  redc256_round_v3(moduloLimb0, moduloLimb1, i3, &i4, invm, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w);
  redc256_round_v3(moduloLimb0, moduloLimb1, i4, &i5, invm, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x);
  redc256_round_v3(moduloLimb0, moduloLimb1, i5, &i6, invm, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y);
  redc256_round_v3(moduloLimb0, moduloLimb1, i6, &i7, invm, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z);

  {
    uint4 M1l0 = mul_hi(moduloLimb0, i7);
    uint4 M1l1 = mul_hi(moduloLimb1, i7);
    R2x += M1l0.x;
    R2y += M1l0.y; Int.v64 = R2x; R2y += Int.v32.y;
    R2z += M1l0.z; Int.v64 = R2y; R2z += Int.v32.y;
    R2w += M1l0.w; Int.v64 = R2z; R2w += Int.v32.y;
    R3x += M1l1.x; Int.v64 = R2w; R3x += Int.v32.y;
    R3y += M1l1.y; Int.v64 = R3x; R3y += Int.v32.y;
    R3z += M1l1.z; Int.v64 = R3y; R3z += Int.v32.y;
    R3w += M1l1.w; Int.v64 = R3z; R3w += Int.v32.y;
  }

  *ResultLimb0 = (uint4){R2x, R2y, R2z, R2w};
  *ResultLimb1 = (uint4){R3x, R3y, R3z, R3w};

  {
    Int.v64 = R3w;
    uint4 l0 = Int.v32.y ? moduloLimb0 : (uint4){0, 0, 0, 0};
    uint4 l1 = Int.v32.y ? moduloLimb1 : (uint4){0, 0, 0, 0};
    sub256(ResultLimb0, ResultLimb1, l0, l1);
  }
}

void redc1_384_v3(uint4 limbs0, uint4 limbs1, uint4 limbs2, uint4 limbs3, uint4 limbs4, uint4 limbs5,
                  uint4 moduloLimb0, uint4 moduloLimb1, uint4 moduloLimb2,
                  uint32_t invm,
                  uint4 *ResultLimb0, uint4 *ResultLimb1, uint4 *ResultLimb2)
{
  ulong R0x = limbs0.x;
  ulong R0y = limbs0.y;
  ulong R0z = limbs0.z;
  ulong R0w = limbs0.w;
  ulong R1x = limbs1.x;
  ulong R1y = limbs1.y;
  ulong R1z = limbs1.z;
  ulong R1w = limbs1.w;
  ulong R2x = limbs2.x;
  ulong R2y = limbs2.y;
  ulong R2z = limbs2.z;
  ulong R2w = limbs2.w;
  ulong R3x = limbs3.x;
  ulong R3y = limbs3.y;
  ulong R3z = limbs3.z;
  ulong R3w = limbs3.w;
  ulong R4x = limbs4.x;
  ulong R4y = limbs4.y;
  ulong R4z = limbs4.z;
  ulong R4w = limbs4.w;
  ulong R5x = limbs5.x;
  ulong R5y = limbs5.y;
  ulong R5z = limbs5.z;
  ulong R5w = limbs5.w;

  uint32_t i0, i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11;

  union {
    uint2 v32;
    ulong v64;
  } Int;

  i0 = limbs0.x * invm;
  {
    uint4 M1l0 = moduloLimb0 * i0;
    uint4 M1l1 = moduloLimb1 * i0;
    uint4 M1l2 = moduloLimb2 * i0;
    R0x += M1l0.x;
    R0y += M1l0.y; Int.v64 = R0x; R0y += Int.v32.y;
    R0z += M1l0.z;
    R0w += M1l0.w;
    R1x += M1l1.x;
    R1y += M1l1.y;
    R1z += M1l1.z;
    R1w += M1l1.w;
    R2x += M1l2.x;
    R2y += M1l2.y;
    R2z += M1l2.z;
    R2w += M1l2.w;
  }

  redc384_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, i0, &i1, invm, &R0y, &R0z, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x);
  redc384_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, i1, &i2, invm, &R0z, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y);
  redc384_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, i2, &i3, invm, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z);
  redc384_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, i3, &i4, invm, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w);
  redc384_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, i4, &i5, invm, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x);
  redc384_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, i5, &i6, invm, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y);
  redc384_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, i6, &i7, invm, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z);
  redc384_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, i7, &i8, invm, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w);
  redc384_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, i8, &i9, invm, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x);
  redc384_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, i9, &i10, invm, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y);
  redc384_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, i10, &i11, invm, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y, &R5z);

  {
    uint4 M1l0 = mul_hi(moduloLimb0, i11);
    uint4 M1l1 = mul_hi(moduloLimb1, i11);
    uint4 M1l2 = mul_hi(moduloLimb2, i11);
    R3x += M1l0.x;
    R3y += M1l0.y; Int.v64 = R3x; R3y += Int.v32.y;
    R3z += M1l0.z; Int.v64 = R3y; R3z += Int.v32.y;
    R3w += M1l0.w; Int.v64 = R3z; R3w += Int.v32.y;
    R4x += M1l1.x; Int.v64 = R3w; R4x += Int.v32.y;
    R4y += M1l1.y; Int.v64 = R4x; R4y += Int.v32.y;
    R4z += M1l1.z; Int.v64 = R4y; R4z += Int.v32.y;
    R4w += M1l1.w; Int.v64 = R4z; R4w += Int.v32.y;
    R5x += M1l2.x; Int.v64 = R4w; R5x += Int.v32.y;
    R5y += M1l2.y; Int.v64 = R5x; R5y += Int.v32.y;
    R5z += M1l2.z; Int.v64 = R5y; R5z += Int.v32.y;
    R5w += M1l2.w; Int.v64 = R5z; R5w += Int.v32.y;
  }

  *ResultLimb0 = (uint4){R3x, R3y, R3z, R3w};
  *ResultLimb1 = (uint4){R4x, R4y, R4z, R4w};
  *ResultLimb2 = (uint4){R5x, R5y, R5z, R5w};


  {
    Int.v64 = R5w;
    uint4 l0 = Int.v32.y ? moduloLimb0 : (uint4){0, 0, 0, 0};
    uint4 l1 = Int.v32.y ? moduloLimb1 : (uint4){0, 0, 0, 0};
    uint4 l2 = Int.v32.y ? moduloLimb2 : (uint4){0, 0, 0, 0};
    sub384(ResultLimb0, ResultLimb1, ResultLimb2, l0, l1, l2);
  }
}




void redc1_448_v3(uint4 limbs0, uint4 limbs1, uint4 limbs2, uint4 limbs3, uint4 limbs4, uint4 limbs5, uint4 limbs6,
                  uint4 moduloLimb0, uint4 moduloLimb1, uint4 moduloLimb2, uint2 moduloLimb3,
                  uint32_t invm,
                  uint4 *ResultLimb0, uint4 *ResultLimb1, uint4 *ResultLimb2, uint2 *ResultLimb3)
{
  ulong R0x = limbs0.x;
  ulong R0y = limbs0.y;
  ulong R0z = limbs0.z;
  ulong R0w = limbs0.w;
  ulong R1x = limbs1.x;
  ulong R1y = limbs1.y;
  ulong R1z = limbs1.z;
  ulong R1w = limbs1.w;
  ulong R2x = limbs2.x;
  ulong R2y = limbs2.y;
  ulong R2z = limbs2.z;
  ulong R2w = limbs2.w;
  ulong R3x = limbs3.x;
  ulong R3y = limbs3.y;
  ulong R3z = limbs3.z;
  ulong R3w = limbs3.w;
  ulong R4x = limbs4.x;
  ulong R4y = limbs4.y;
  ulong R4z = limbs4.z;
  ulong R4w = limbs4.w;
  ulong R5x = limbs5.x;
  ulong R5y = limbs5.y;
  ulong R5z = limbs5.z;
  ulong R5w = limbs5.w;
  ulong R6x = limbs6.x;
  ulong R6y = limbs6.y;
  ulong R6z = limbs6.z;
  ulong R6w = limbs6.w;

  uint32_t i0, i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11, i12, i13;

  union {
    uint2 v32;
    ulong v64;
  } Int;

  i0 = limbs0.x * invm;
  {
    uint4 M1l0 = moduloLimb0 * i0;
    uint4 M1l1 = moduloLimb1 * i0;
    uint4 M1l2 = moduloLimb2 * i0;
    uint2 M1l3 = moduloLimb3 * i0;
    R0x += M1l0.x;
    R0y += M1l0.y; Int.v64 = R0x; R0y += Int.v32.y;
    R0z += M1l0.z;
    R0w += M1l0.w;
    R1x += M1l1.x;
    R1y += M1l1.y;
    R1z += M1l1.z;
    R1w += M1l1.w;
    R2x += M1l2.x;
    R2y += M1l2.y;
    R2z += M1l2.z;
    R2w += M1l2.w;
    R3x += M1l3.x;
    R3y += M1l3.y;
  }

  redc448_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, moduloLimb3, i0, &i1, invm, &R0y, &R0z, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z);
  redc448_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, moduloLimb3, i1, &i2, invm, &R0z, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w);
  redc448_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, moduloLimb3, i2, &i3, invm, &R0w, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x);
  redc448_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, moduloLimb3, i3, &i4, invm, &R1x, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y);
  redc448_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, moduloLimb3, i4, &i5, invm, &R1y, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z);
  redc448_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, moduloLimb3, i5, &i6, invm, &R1z, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w);
  redc448_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, moduloLimb3, i6, &i7, invm, &R1w, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x);
  redc448_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, moduloLimb3, i7, &i8, invm, &R2x, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y);
  redc448_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, moduloLimb3, i8, &i9, invm, &R2y, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y, &R5z);
  redc448_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, moduloLimb3, i9 , &i10, invm, &R2z, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y, &R5z, &R5w);
  redc448_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, moduloLimb3, i10, &i11, invm, &R2w, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y, &R5z, &R5w, &R6x);
  redc448_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, moduloLimb3, i11, &i12, invm, &R3x, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y, &R5z, &R5w, &R6x, &R6y);
  redc448_round_v3(moduloLimb0, moduloLimb1, moduloLimb2, moduloLimb3, i12, &i13, invm, &R3y, &R3z, &R3w, &R4x, &R4y, &R4z, &R4w, &R5x, &R5y, &R5z, &R5w, &R6x, &R6y, &R6z);

  {
    uint4 M1l0 = mul_hi(moduloLimb0, i13);
    uint4 M1l1 = mul_hi(moduloLimb1, i13);
    uint4 M1l2 = mul_hi(moduloLimb2, i13);
    uint2 M1l3 = mul_hi(moduloLimb3, i13);

    R3z += M1l0.x;
    R3w += M1l0.y; Int.v64 = R3z; R3w += Int.v32.y;
    R4x += M1l0.z; Int.v64 = R3w; R4x += Int.v32.y;
    R4y += M1l0.w; Int.v64 = R4x; R4y += Int.v32.y;
    R4z += M1l1.x; Int.v64 = R4y; R4z += Int.v32.y;
    R4w += M1l1.y; Int.v64 = R4z; R4w += Int.v32.y;
    R5x += M1l1.z; Int.v64 = R4w; R5x += Int.v32.y;
    R5y += M1l1.w; Int.v64 = R5x; R5y += Int.v32.y;
    R5z += M1l2.x; Int.v64 = R5y; R5z += Int.v32.y;
    R5w += M1l2.y; Int.v64 = R5z; R5w += Int.v32.y;
    R6x += M1l2.z; Int.v64 = R5w; R6x += Int.v32.y;
    R6y += M1l2.w; Int.v64 = R6x; R6y += Int.v32.y;
    R6z += M1l3.x; Int.v64 = R6y; R6z += Int.v32.y;
    R6w += M1l3.y; Int.v64 = R6z; R6w += Int.v32.y;
  }

  *ResultLimb0 = (uint4){R3z, R3w, R4x, R4y};
  *ResultLimb1 = (uint4){R4z, R4w, R5x, R5y};
  *ResultLimb2 = (uint4){R5z, R5w, R6x, R6y};
  *ResultLimb3 = (uint2){R6z, R6w};


  {
    Int.v64 = R6w;
    uint4 l0 = Int.v32.y ? moduloLimb0 : (uint4){0, 0, 0, 0};
    uint4 l1 = Int.v32.y ? moduloLimb1 : (uint4){0, 0, 0, 0};
    uint4 l2 = Int.v32.y ? moduloLimb2 : (uint4){0, 0, 0, 0};
    uint2 l3 = Int.v32.y ? moduloLimb3 : (uint2){0, 0};
    sub448(ResultLimb0, ResultLimb1, ResultLimb2, ResultLimb3, l0, l1, l2, l3);
  }
}




uint32_t dec128(uint4 *a0)
{
  --(*a0).x;
  (*a0).y -= ((*a0).x == 0xFFFFFFFF);
  (*a0).z -= ((*a0).y == 0xFFFFFFFF);
  (*a0).w -= ((*a0).z == 0xFFFFFFFF);
  return (*a0).w == 0xFFFFFFFF;
}

uint32_t dec256(uint4 *a0, uint4 *a1)
{
  --(*a0).x;
  (*a0).y -= ((*a0).x == 0xFFFFFFFF);
  (*a0).z -= ((*a0).y == 0xFFFFFFFF);
  (*a0).w -= ((*a0).z == 0xFFFFFFFF);
  (*a1).x -= ((*a0).w == 0xFFFFFFFF);
  (*a1).y -= ((*a1).x == 0xFFFFFFFF);
  (*a1).z -= ((*a1).y == 0xFFFFFFFF);
  (*a1).w -= ((*a1).w == 0xFFFFFFFF);
  return (*a1).w == 0xFFFFFFFF;
}

void inc384(uint4 *a0, uint4 *a1, uint4 *a2)
{
  ++(*a0).x;
  (*a0).y += ((*a0).x == 0);
  (*a0).z += ((*a0).y == 0);
  (*a0).w += ((*a0).z == 0);

  (*a1).x += ((*a0).w == 0);
  (*a1).y += ((*a1).x == 0);
  (*a1).z += ((*a1).y == 0);
  (*a1).w += ((*a1).z == 0);

  (*a2).x += ((*a1).w == 0);
  (*a2).y += ((*a2).x == 0);
  (*a2).z += ((*a2).y == 0);
  (*a2).w += ((*a2).z == 0);
}

void dec384(uint4 *a0, uint4 *a1, uint4 *a2)
{
  --(*a0).x;
  (*a0).y -= ((*a0).x == 0xFFFFFFFF);
  (*a0).z -= ((*a0).y == 0xFFFFFFFF);
  (*a0).w -= ((*a0).z == 0xFFFFFFFF);
  (*a1).x -= ((*a0).w == 0xFFFFFFFF);
  (*a1).y -= ((*a1).x == 0xFFFFFFFF);
  (*a1).z -= ((*a1).y == 0xFFFFFFFF);
  (*a1).w -= ((*a1).z == 0xFFFFFFFF);
  (*a2).x -= ((*a1).w == 0xFFFFFFFF);
  (*a2).y -= ((*a2).x == 0xFFFFFFFF);
  (*a2).z -= ((*a2).y == 0xFFFFFFFF);
  (*a2).w -= ((*a2).z == 0xFFFFFFFF);
}

void montgomeryMul256(uint4 *rl0, uint4 *rl1,
                      uint4 ml0, uint4 ml1,
                      uint4 modl0, uint4 modl1,
                      uint32_t inverted)
{
  uint4 m0, m1, m2, m3;
  mul256schoolBook_v3(*rl0, *rl1, ml0, ml1, &m0, &m1, &m2, &m3);
  redc1_256_v3(m0, m1, m2, m3, modl0, modl1, inverted, rl0, rl1);
}

void FermatTest256(uint4 limbs0, uint4 limbs1,
                   uint4 *resultLimbs0, uint4 *resultLimbs1)
{

  __private uint4 precomputed[2*16*2];
  uint32_t inverted = invert_limb(limbs0.x);

  uint2 bitSize;
  uint4 BmLimbs0, BmLimbs1;
  {
    uint4 dl2 = {1, 0, 0, 0};
    uint4 dl1 = {0, 0, 0, 0};
    uint4 dl0 = {0, 0, 0, 0};


    modulo384to256(dl0, dl1, dl2, limbs0, limbs1, &BmLimbs0, &BmLimbs1);
    precomputed[2*0 + 0] = BmLimbs0;
    precomputed[2*0 + 1] = BmLimbs1;


    dl2.x = 2;
    bitSize = modulo384to256(dl0, dl1, dl2, limbs0, limbs1, &BmLimbs0, &BmLimbs1);
    precomputed[2*1 + 0] = BmLimbs0;
    precomputed[2*1 + 1] = BmLimbs1;
    --bitSize.y;
    if (bitSize.y == 0) {
      --bitSize.x;
      bitSize.y = 32;
    }
  }


  uint4 m0, m1, m2, m3;
  uint4 redcl0 = BmLimbs0,
        redcl1 = BmLimbs1;
  for (unsigned i = 2; i < 16; i++) {
    montgomeryMul256(&redcl0, &redcl1, BmLimbs0, BmLimbs1, limbs0, limbs1, inverted);
    precomputed[2*i + 0] = redcl0;
    precomputed[2*i + 1] = redcl1;
  }

  uint4 exp0 = limbs0;
  uint4 exp1 = limbs1;
  --exp0.x;

  for (unsigned i = 0; i < 8-bitSize.x; i++)
    lshiftByLimb2(&exp0, &exp1);

  barrier(CLK_LOCAL_MEM_FENCE);
  exp1.w <<= (bitSize.y ? 32-bitSize.y : 0);
  redcl0 = BmLimbs0;
  redcl1 = BmLimbs1;

  unsigned shiftCount = 0;
  unsigned square = 1;
  unsigned groupSize = (bitSize.y % 4) ? (bitSize.y % 4) : 4;
  unsigned bitcount = bitSize.y;
  while (bitSize.x) {
    while (bitcount) {
      uint4 mult0, mult1;
      if (!square) {
        unsigned index = 2 * (exp1.w >> (32 - shiftCount));
        mult0 = precomputed[index];
        mult1 = precomputed[index+1];
      }

      groupSize = square ? groupSize : 1;
      exp1.w <<= shiftCount;
      bitcount -= shiftCount;
      shiftCount = square ? groupSize : 0;
      while (groupSize) {
        mult0 = square ? redcl0 : mult0;
        mult1 = square ? redcl1 : mult1;
        montgomeryMul256(&redcl0, &redcl1, mult0, mult1, limbs0, limbs1, inverted);
        groupSize--;
      }

      square ^= 1;
      groupSize = 4;
    }

    lshiftByLimb2(&exp0, &exp1);
    --bitSize.x;
    bitcount = 32;
  }

  barrier(CLK_LOCAL_MEM_FENCE);
  redc1_256_v3(redcl0, redcl1, 0, 0, limbs0, limbs1, inverted, resultLimbs0, resultLimbs1);
  return;
}



__kernel void fermatTestBenchMark256(__global uint32_t *numbers,
                                     __global uint32_t *result,
                                     unsigned elementsNum)
{
  __global uint4 *numbersPtr = (__global uint4*)numbers;
  __global uint4 *resultPtr = (__global uint4*)result;

  unsigned globalSize = get_global_size(0);
  for (unsigned repeatNum = 0; repeatNum < 1; repeatNum++) {
    for (unsigned i = get_global_id(0); i < elementsNum; i += globalSize) {
      uint4 numbersLimbs0 = numbersPtr[i*2];
      uint4 numbersLimbs1 = numbersPtr[i*2+1];

      uint4 resultLimbs0;
      uint4 resultLimbs1;
      FermatTest256(numbersLimbs0, numbersLimbs1, &resultLimbs0, &resultLimbs1);

      resultPtr[i*2] = resultLimbs0;
      resultPtr[i*2+1] = resultLimbs1;
    }
  }
}

void montgomeryMul384(uint4 *rl0, uint4 *rl1, uint4 *rl2,
                      uint4 ml0, uint4 ml1, uint4 ml2,
                      uint4 modl0, uint4 modl1, uint4 modl2,
                      uint32_t inverted)
{
  uint4 m0, m1, m2, m3, m4, m5;
  mul384schoolBook_v3(*rl0, *rl1, *rl2, ml0, ml1, ml2, &m0, &m1, &m2, &m3, &m4, &m5);
  redc1_384_v3(m0, m1, m2, m3, m4, m5, modl0, modl1, modl2, inverted, rl0, rl1, rl2);
}

void FermatTest384(uint4 limbs0, uint4 limbs1, uint4 limbs2,
                   uint4 *resultLimbs0, uint4 *resultLimbs1, uint4 *resultLimbs2)
{

  __private uint4 precomputed[3*16];
  uint32_t inverted = invert_limb(limbs0.x);

  uint2 bitSize;
  uint4 BmLimbs0, BmLimbs1, BmLimbs2;
  {
    uint4 dl3 = {1, 0, 0, 0};
    uint4 dl2 = {0, 0, 0, 0};
    uint4 dl1 = {0, 0, 0, 0};
    uint4 dl0 = {0, 0, 0, 0};


    modulo512to384(dl0, dl1, dl2, dl3, limbs0, limbs1, limbs2, &BmLimbs0, &BmLimbs1, &BmLimbs2);
    precomputed[3*0 + 0] = BmLimbs0;
    precomputed[3*0 + 1] = BmLimbs1;
    precomputed[3*0 + 2] = BmLimbs2;


    dl3.x = 2;
    bitSize = modulo512to384(dl0, dl1, dl2, dl3, limbs0, limbs1, limbs2, &BmLimbs0, &BmLimbs1, &BmLimbs2);
    precomputed[3*1 + 0] = BmLimbs0;
    precomputed[3*1 + 1] = BmLimbs1;
    precomputed[3*1 + 2] = BmLimbs2;
    --bitSize.y;
    if (bitSize.y == 0) {
      --bitSize.x;
      bitSize.y = 32;
    }
  }


  uint4 m0, m1, m2, m3, m4, m5;
  uint4 redcl0 = BmLimbs0,
        redcl1 = BmLimbs1,
        redcl2 = BmLimbs2;
  for (unsigned i = 2; i < 16; i++) {
    montgomeryMul384(&redcl0, &redcl1, &redcl2, BmLimbs0, BmLimbs1, BmLimbs2, limbs0, limbs1, limbs2, inverted);
    precomputed[3*i + 0] = redcl0;
    precomputed[3*i + 1] = redcl1;
    precomputed[3*i + 2] = redcl2;
  }

  uint4 exp0 = limbs0;
  uint4 exp1 = limbs1;
  uint4 exp2 = limbs2;
  --exp0.x;

  for (unsigned i = 0; i < 12-bitSize.x; i++)
    lshiftByLimb3(&exp0, &exp1, &exp2);

  barrier(CLK_LOCAL_MEM_FENCE);
  exp2.w <<= (bitSize.y ? 32-bitSize.y : 0);
  redcl0 = BmLimbs0;
  redcl1 = BmLimbs1;
  redcl2 = BmLimbs2;

  unsigned shiftCount = 0;
  unsigned square = 1;
  unsigned groupSize = (bitSize.y % 4) ? (bitSize.y % 4) : 4;
  unsigned bitcount = bitSize.y;
  while (bitSize.x) {
    while (bitcount) {
      uint4 mult0, mult1, mult2;
      if (!square) {
        unsigned index = 3 * (exp2.w >> (32 - shiftCount));
        mult0 = precomputed[index];
        mult1 = precomputed[index+1];
        mult2 = precomputed[index+2];
      }

      groupSize = square ? groupSize : 1;
      exp2.w <<= shiftCount;
      bitcount -= shiftCount;
      shiftCount = square ? groupSize : 0;
      while (groupSize) {
        mult0 = square ? redcl0 : mult0;
        mult1 = square ? redcl1 : mult1;
        mult2 = square ? redcl2 : mult2;
        montgomeryMul384(&redcl0, &redcl1, &redcl2, mult0, mult1, mult2, limbs0, limbs1, limbs2, inverted);
        groupSize--;
      }

      square ^= 1;
      groupSize = 4;
    }

    lshiftByLimb3(&exp0, &exp1, &exp2);
    --bitSize.x;
    bitcount = 32;
  }

  barrier(CLK_LOCAL_MEM_FENCE);
  redc1_384_v3(redcl0, redcl1, redcl2, 0, 0, 0, limbs0, limbs1, limbs2, inverted, resultLimbs0, resultLimbs1, resultLimbs2);
  return;
}


__kernel void fermatTestBenchMark384(__global uint32_t *numbers,
                                     __global uint32_t *result,
                                     unsigned elementsNum)
{
  __global uint4 *numbersPtr = (__global uint4*)numbers;
  __global uint4 *resultPtr = (__global uint4*)result;

  unsigned globalSize = get_global_size(0);
  for (unsigned repeatNum = 0; repeatNum < 1; repeatNum++) {
    for (unsigned i = get_global_id(0); i < elementsNum; i += globalSize) {
      uint4 numbersLimbs0 = numbersPtr[i*3];
      uint4 numbersLimbs1 = numbersPtr[i*3+1];
      uint4 numbersLimbs2 = numbersPtr[i*3+2];

      uint4 resultLimbs0;
      uint4 resultLimbs1;
      uint4 resultLimbs2;
      FermatTest384(numbersLimbs0, numbersLimbs1, numbersLimbs2, &resultLimbs0, &resultLimbs1, &resultLimbs2);

      resultPtr[i*3] = resultLimbs0;
      resultPtr[i*3+1] = resultLimbs1;
      resultPtr[i*3+2] = resultLimbs2;
    }
  }
}

void montgomeryMul448(uint4 *rl0, uint4 *rl1, uint4 *rl2, uint2 *rl3,
                      uint4 ml0, uint4 ml1, uint4 ml2, uint2 ml3,
                      uint4 modl0, uint4 modl1, uint4 modl2, uint2 modl3,
                      uint32_t inverted)
{
  uint4 m0, m1, m2, m3, m4, m5, m6;
  mul448schoolBook_v3(*rl0, *rl1, *rl2, *rl3, ml0, ml1, ml2, ml3, &m0, &m1, &m2, &m3, &m4, &m5, &m6);
  redc1_448_v3(m0, m1, m2, m3, m4, m5, m6, modl0, modl1, modl2, modl3, inverted, rl0, rl1, rl2, rl3);
}

void FermatTest448(uint4 limbs0, uint4 limbs1, uint4 limbs2, uint2 limbs3,
                   uint4 *resultLimbs0, uint4 *resultLimbs1, uint4 *resultLimbs2, uint2 *resultLimbs3)
{

  __private uint4 precomputed[4*16];
  uint32_t inverted = invert_limb(limbs0.x);

  uint2 bitSize;
  uint4 BmLimbs0, BmLimbs1, BmLimbs2, BmLimbs3;
  {
    uint4 dl4 = {0, 0, 0, 0};
    uint4 dl3 = {0, 0, 1, 0};
    uint4 dl2 = {0, 0, 0, 0};
    uint4 dl1 = {0, 0, 0, 0};
    uint4 dl0 = {0, 0, 0, 0};


    modulo640to512(dl0, dl1, dl2, dl3, dl4,
                   limbs0, limbs1, limbs2, (uint4){limbs3.x, limbs3.y, 0, 0},
                   &BmLimbs0, &BmLimbs1, &BmLimbs2, &BmLimbs3);
    precomputed[4*0 + 0] = BmLimbs0;
    precomputed[4*0 + 1] = BmLimbs1;
    precomputed[4*0 + 2] = BmLimbs2;
    precomputed[4*0 + 3] = BmLimbs3;


    dl3.z = 2;
    bitSize = modulo640to512(dl0, dl1, dl2, dl3, dl4,
                             limbs0, limbs1, limbs2, (uint4){limbs3.x, limbs3.y, 0, 0},
                             &BmLimbs0, &BmLimbs1, &BmLimbs2, &BmLimbs3);
    precomputed[4*1 + 0] = BmLimbs0;
    precomputed[4*1 + 1] = BmLimbs1;
    precomputed[4*1 + 2] = BmLimbs2;
    precomputed[4*1 + 3] = BmLimbs3;
    --bitSize.y;
    if (bitSize.y == 0) {
      --bitSize.x;
      bitSize.y = 32;
    }
  }


  uint4 redcl0 = BmLimbs0,
        redcl1 = BmLimbs1,
        redcl2 = BmLimbs2;
  uint2 redcl3 = BmLimbs3.xy;

  for (unsigned i = 2; i < 16; i++) {
    montgomeryMul448(&redcl0, &redcl1, &redcl2, &redcl3,
                     BmLimbs0, BmLimbs1, BmLimbs2, BmLimbs3.xy,
                     limbs0, limbs1, limbs2, limbs3,
                     inverted);
    precomputed[4*i + 0] = redcl0;
    precomputed[4*i + 1] = redcl1;
    precomputed[4*i + 2] = redcl2;
    precomputed[4*i + 3] = (uint4){redcl3.x, redcl3.y, 0, 0};
  }

  uint4 exp0 = limbs0;
  uint4 exp1 = limbs1;
  uint4 exp2 = limbs2;
  uint4 exp3 = {limbs3.x, limbs3.y, 0, 0};
  --exp0.x;

  for (unsigned i = 0; i < 16-bitSize.x; i++)
    lshiftByLimb4(&exp0, &exp1, &exp2, &exp3);

  barrier(CLK_LOCAL_MEM_FENCE);
  exp3.w <<= (bitSize.y ? 32-bitSize.y : 0);
  redcl0 = BmLimbs0;
  redcl1 = BmLimbs1;
  redcl2 = BmLimbs2;
  redcl3 = BmLimbs3.xy;

  unsigned shiftCount = 0;
  unsigned square = 1;
  unsigned groupSize = (bitSize.y % 4) ? (bitSize.y % 4) : 4;
  unsigned bitcount = bitSize.y;
  while (bitSize.x) {
    while (bitcount) {
      uint4 mult0, mult1, mult2;
      uint2 mult3;
      if (!square) {
        unsigned index = 4 * (exp3.w >> (32 - shiftCount));
        mult0 = precomputed[index];
        mult1 = precomputed[index+1];
        mult2 = precomputed[index+2];
        mult3 = precomputed[index+3].xy;
      }

      groupSize = square ? groupSize : 1;
      exp3.w <<= shiftCount;
      bitcount -= shiftCount;
      shiftCount = square ? groupSize : 0;
      while (groupSize) {
        mult0 = square ? redcl0 : mult0;
        mult1 = square ? redcl1 : mult1;
        mult2 = square ? redcl2 : mult2;
        mult3 = square ? redcl3 : mult3;
        montgomeryMul448(&redcl0, &redcl1, &redcl2, &redcl3,
                         mult0, mult1, mult2, mult3,
                         limbs0, limbs1, limbs2, limbs3,
                         inverted);
        groupSize--;
      }

      square ^= 1;
      groupSize = 4;
    }

    lshiftByLimb4(&exp0, &exp1, &exp2, &exp3);
    --bitSize.x;
    bitcount = 32;
  }

  barrier(CLK_LOCAL_MEM_FENCE);
  redc1_448_v3(redcl0, redcl1, redcl2, (uint4){redcl3.x, redcl3.y, 0, 0}, 0, 0, 0,
               limbs0, limbs1, limbs2, limbs3,
               inverted,
               resultLimbs0, resultLimbs1, resultLimbs2, resultLimbs3);
}

__kernel void fermatTestBenchMark448(__global uint32_t *numbers,
                                     __global uint32_t *result,
                                     unsigned elementsNum)
{
  unsigned globalSize = get_global_size(0);
  for (unsigned repeatNum = 0; repeatNum < 1; repeatNum++) {
    for (unsigned i = get_global_id(0); i < elementsNum; i += globalSize) {
      uint4 numbersLimbs0 = {numbers[i*14], numbers[i*14+1], numbers[i*14+2], numbers[i*14+3]};
      uint4 numbersLimbs1 = {numbers[i*14+4], numbers[i*14+5], numbers[i*14+6], numbers[i*14+7]};
      uint4 numbersLimbs2 = {numbers[i*14+8], numbers[i*14+9], numbers[i*14+10], numbers[i*14+11]};
      uint2 numbersLimbs3 = {numbers[i*14+12], numbers[i*14+13]};

      uint4 resultLimbs0;
      uint4 resultLimbs1;
      uint4 resultLimbs2;
      uint2 resultLimbs3;
      FermatTest448(numbersLimbs0, numbersLimbs1, numbersLimbs2, numbersLimbs3,
                    &resultLimbs0, &resultLimbs1, &resultLimbs2, &resultLimbs3);

      result[i*14] = resultLimbs0.x;
      result[i*14+1] = resultLimbs0.y;
      result[i*14+2] = resultLimbs0.z;
      result[i*14+3] = resultLimbs0.w;
      result[i*14+4] = resultLimbs1.x;
      result[i*14+5] = resultLimbs1.y;
      result[i*14+6] = resultLimbs1.z;
      result[i*14+7] = resultLimbs1.w;
      result[i*14+8] = resultLimbs2.x;
      result[i*14+9] = resultLimbs2.y;
      result[i*14+10] = resultLimbs2.z;
      result[i*14+11] = resultLimbs2.w;
      result[i*14+12] = resultLimbs3.x;
      result[i*14+13] = resultLimbs3.y;
    }
  }
}


__kernel void modulo384to256test(__global uint32_t *dividends,
                                 __global uint32_t *divisors,
                                 __global uint32_t *modulos,
                                 unsigned elementsNum)
{
  __global uint4 *dividendPtr = (__global uint4*)dividends;
  __global uint4 *divisorPtr = (__global uint4*)divisors;
  __global uint4 *modulosPtr = (__global uint4*)modulos;

  unsigned globalSize = get_global_size(0);

  for (unsigned repeatNum = 0; repeatNum < 32; repeatNum++) {
    for (unsigned i = get_global_id(0); i < elementsNum; i += globalSize) {
      uint4 dividendLimbs0 = dividendPtr[i*3];
      uint4 dividendLimbs1 = dividendPtr[i*3+1];
      uint4 dividendLimbs2 = dividendPtr[i*3+2];

      uint4 divisorLimbs0 = divisorPtr[i*2];
      uint4 divisorLimbs1 = divisorPtr[i*2+1];

      uint4 moduloLimb0;
      uint4 moduloLimb1;

      modulo384to256(dividendLimbs0, dividendLimbs1, dividendLimbs2,
                     divisorLimbs0, divisorLimbs1,
                     &moduloLimb0, &moduloLimb1);

      modulosPtr[i*2] = moduloLimb0;
      modulosPtr[i*2+1] = moduloLimb1;
    }
  }
}

__kernel void modulo512to384test(__global uint32_t *dividends,
                                 __global uint32_t *divisors,
                                 __global uint32_t *modulos,
                                 unsigned elementsNum)
{
  __global uint4 *dividendPtr = (__global uint4*)dividends;
  __global uint4 *divisorPtr = (__global uint4*)divisors;
  __global uint4 *modulosPtr = (__global uint4*)modulos;

  unsigned globalSize = get_global_size(0);

  for (unsigned repeatNum = 0; repeatNum < 32; repeatNum++) {
    for (unsigned i = get_global_id(0); i < elementsNum; i += globalSize) {
      uint4 dividendLimbs0 = dividendPtr[i*4];
      uint4 dividendLimbs1 = dividendPtr[i*4+1];
      uint4 dividendLimbs2 = dividendPtr[i*4+2];
      uint4 dividendLimbs3 = dividendPtr[i*4+3];

      uint4 divisorLimbs0 = divisorPtr[i*3];
      uint4 divisorLimbs1 = divisorPtr[i*3+1];
      uint4 divisorLimbs2 = divisorPtr[i*3+2];

      uint4 moduloLimb0;
      uint4 moduloLimb1;
      uint4 moduloLimb2;

      modulo512to384(dividendLimbs0, dividendLimbs1, dividendLimbs2, dividendLimbs3,
                     divisorLimbs0, divisorLimbs1, divisorLimbs2,
                     &moduloLimb0, &moduloLimb1, &moduloLimb2);

      modulosPtr[i*3] = moduloLimb0;
      modulosPtr[i*3+1] = moduloLimb1;
      modulosPtr[i*3+2] = moduloLimb2;
    }
  }
}

__kernel void modulo640to512test(__global uint32_t *dividends,
                                 __global uint32_t *divisors,
                                 __global uint32_t *modulos,
                                 unsigned elementsNum)
{
  __global uint4 *dividendPtr = (__global uint4*)dividends;
  __global uint4 *divisorPtr = (__global uint4*)divisors;
  __global uint4 *modulosPtr = (__global uint4*)modulos;

  unsigned globalSize = get_global_size(0);

  for (unsigned repeatNum = 0; repeatNum < 32; repeatNum++) {
    for (unsigned i = get_global_id(0); i < elementsNum; i += globalSize) {
      uint4 dividendLimbs0 = dividendPtr[i*5];
      uint4 dividendLimbs1 = dividendPtr[i*5+1];
      uint4 dividendLimbs2 = dividendPtr[i*5+2];
      uint4 dividendLimbs3 = dividendPtr[i*5+3];
      uint4 dividendLimbs4 = dividendPtr[i*5+4];

      uint4 divisorLimbs0 = divisorPtr[i*4];
      uint4 divisorLimbs1 = divisorPtr[i*4+1];
      uint4 divisorLimbs2 = divisorPtr[i*4+2];
      uint4 divisorLimbs3 = divisorPtr[i*4+3];

      uint4 moduloLimb0;
      uint4 moduloLimb1;
      uint4 moduloLimb2;
      uint4 moduloLimb3;

      modulo640to512(dividendLimbs0, dividendLimbs1, dividendLimbs2, dividendLimbs3, dividendLimbs4,
                     divisorLimbs0, divisorLimbs1, divisorLimbs2, divisorLimbs3,
                     &moduloLimb0, &moduloLimb1, &moduloLimb2, &moduloLimb3);

      modulosPtr[i*4] = moduloLimb0;
      modulosPtr[i*4+1] = moduloLimb1;
      modulosPtr[i*4+2] = moduloLimb2;
      modulosPtr[i*4+3] = moduloLimb3;
    }
  }
}

__kernel void searchNonce(__constant uint4 *block,
                          __global struct GPUNonceAndHash *nonceAndHash,
                          __constant uint32_t *primes,
                          __global uint64_t *multipliers64,
                          __global uint32_t *offsets64)
{
  __local uint4 hash[2*256];
  __local uint8_t hasModulo[256];
  __global struct GPUNonceAndHash *context = &nonceAndHash[get_group_id(0)];
  uint32_t nonceIdx = context->currentNonce + 1;

  barrier(CLK_GLOBAL_MEM_FENCE);
  if (nonceIdx >= context->totalNonces) {
    uint4 m0 = block[0];
    uint4 m1 = block[1];
    uint4 m2 = block[2];
    uint4 m3 = block[3];
    uint4 m4 = block[4];

    sha256SwapByteOrder(&m0);
    sha256SwapByteOrder(&m1);
    sha256SwapByteOrder(&m2);
    sha256SwapByteOrder(&m3);
    sha256SwapByteOrder(&m4);

    uint4 hash1l0, hash1l1;
    uint4 hash2l0, hash2l1;
    uint4 targetHashl0, targetHashl1;
    uint32_t targetNonce;

    uint32_t currentNonce = context->nonce[nonceIdx-1];
    currentNonce = (currentNonce == 0) ?
      get_global_id(0) : currentNonce - (currentNonce % 256) + get_global_size(0) + get_local_id(0);
    unsigned trialDivisionPassedCounter = 0;

    while (trialDivisionPassedCounter < 256) {
      m4.w = (rotate(currentNonce & ES[0],24U)|rotate(currentNonce & ES[1],8U));
      SHA256_fresh(&hash1l0, &hash1l1, m0, m1, m2, m3);
      sha256(&hash1l0, &hash1l1,
             m4, (uint4){0x80000000, 0, 0, 0}, (uint4){0, 0, 0, 0}, (uint4){0, 0, 0, 0x00000280});
      SHA256_fresh(&hash2l0, &hash2l1,
                   hash1l0, hash1l1, (uint4){0x80000000, 0, 0, 0}, (uint4){0, 0, 0, 0x00000100});
      sha256SwapByteOrder(&hash2l0);
      sha256SwapByteOrder(&hash2l1);
      barrier(CLK_LOCAL_MEM_FENCE);
      hash[get_local_id(0)*2 + 0] = hash2l0;
      hash[get_local_id(0)*2 + 1] = hash2l1;
      barrier(CLK_LOCAL_MEM_FENCE);

      for (unsigned i = 0; (i < get_local_size(0)) && (trialDivisionPassedCounter < 256); i++) {
        hash1l0 = hash[i*2 + 0];
        hash1l1 = hash[i*2 + 1];
        if (!((hash1l1.w >> 31) & hash1l0.x))
          continue;

        unsigned passed = 1;
        for (unsigned j = 0, divIdx = get_local_id(0)+1; divIdx < 1024+1; j++, divIdx += 256) {
          barrier(CLK_LOCAL_MEM_FENCE);
          hasModulo[get_local_id(0)] = (longModuloByMul256(hash1l0,
                                                           hash1l1,
                                                           primes[divIdx],
                                                           multipliers64[divIdx],
                                                           offsets64[divIdx]) == 0);
          barrier(CLK_LOCAL_MEM_FENCE);
          uint4 M = {0, 0, 0, 0};
          for (unsigned k = 0; k < 256/16; k++)
            M |= ((__local uint4*)hasModulo)[k];
          barrier(CLK_LOCAL_MEM_FENCE);
          M.xy |= M.zw;
          M.x |= M.y;
          if (M.x) {
            passed = 0;
            break;
          }
        }

        if (passed) {
          if (get_local_id(0) == trialDivisionPassedCounter) {
            targetHashl0 = hash1l0;
            targetHashl1 = hash1l1;
            targetNonce = currentNonce - (currentNonce % 256) + i;
          }
          trialDivisionPassedCounter++;
        }
      }

      currentNonce += get_global_size(0);
    }
    barrier(CLK_LOCAL_MEM_FENCE);

    unsigned isPrime;
    {
      uint4 modPowL0, modPowL1;
      FermatTest256(targetHashl0, targetHashl1, &modPowL0, &modPowL1);
      --modPowL0.x;
      modPowL0 |= modPowL1;
      modPowL0.xy |= modPowL1.zw;
      modPowL0.x |= modPowL0.y;
      isPrime = modPowL0.x == 0;
    }

    hasModulo[get_local_id(0)] = isPrime;
    barrier(CLK_LOCAL_MEM_FENCE);

    uint32_t index, sum = 0;
    unsigned threadGrId = get_local_id(0) / 4;
    for (unsigned i = 0; i < 256 / 4; i++)
      sum += (i < threadGrId) ? ((__local uint32_t*)hasModulo)[i] : 0;

    index = (sum & 0xFF) + ((sum >> 8) & 0xFF) + ((sum >> 16) & 0xFF) + (sum >> 24);
    index += (get_local_id(0) % 4 >= 1) ? hasModulo[get_local_id(0) - 1] : 0;
    index += (get_local_id(0) % 4 >= 2) ? hasModulo[get_local_id(0) - 2] : 0;
    index += (get_local_id(0) % 4 >= 3) ? hasModulo[get_local_id(0) - 3] : 0;

    if (isPrime) {
      context->hash[index*2] = targetHashl0;
      context->hash[index*2 + 1] = targetHashl1;
      context->nonce[index] = targetNonce;
    }

    nonceIdx = 0;
    context->currentNonce = 0;
    if (get_local_id(0) == 256 - 1)
      context->totalNonces = index;
    barrier(CLK_GLOBAL_MEM_FENCE);
  } else {
    context->currentNonce = nonceIdx;
  }
}


__kernel void sieve(__global uint32_t *cunningham1Bitfield,
                    __global uint32_t *cunningham2Bitfield,
                    __global uint32_t *bitwinBitfield,
                    __constant uint4 *primorial,
                    __global struct GPUNonceAndHash *nonceAndHash,
                    __constant uint32_t *primes,
                    __global uint64_t *multipliers64,
                    __global uint32_t *offsets64)
{
  __local uint8_t localCunningham1[8192];
  __local uint8_t localCunningham2[8192];
  __global struct GPUNonceAndHash *context = &nonceAndHash[get_group_id(0)];
  uint32_t nonceIdx = context->currentNonce;

  uint4 M0, M1, M2, M3;
  mul256schoolBook_v3(context->hash[nonceIdx*2], context->hash[nonceIdx*2+1],
                      primorial[0], primorial[1],
                      &M0, &M1, &M2, &M3);

  weave(M0, M1, M2,
        cunningham1Bitfield + get_group_id(0) * ((8192*(256))*(9 +1))/32,
        cunningham2Bitfield + get_group_id(0) * ((8192*(256))*(9 +1))/32,
        bitwinBitfield + get_group_id(0) * ((8192*(256))*(9 +1))/32,
        localCunningham1,
        localCunningham2,
        primes,
        multipliers64,
        offsets64,
        get_local_size(0) - 256 + 112);
}

void mul384_1(uint4 l0, uint4 l1, uint4 l2, uint32_t m,
              uint4 *r0, uint4 *r1, uint4 *r2)
{
  *r0 = l0 * m;
  *r1 = l1 * m;
  *r2 = l2 * m;

  uint4 h0 = mul_hi(l0, m);
  uint4 h1 = mul_hi(l1, m);
  uint4 h2 = mul_hi(l2, m);

  add384(r0, r1, r2,
         (uint4){0, h0.x, h0.y, h0.z},
         (uint4){h0.w, h1.x, h1.y, h1.z},
         (uint4){h1.w, h2.x, h2.y, h2.z});
}


unsigned extractMultipliers2(__global struct GPUNonceAndHash *sieve,
                             __constant uint4 *primorial,
                             __global uint32_t *ptr,
                             __local uint32_t *multipliersPerThread,
                             __local uint32_t *multipliersNum,
                             __global struct FermatQueue *queue,
                             unsigned modifier,
                             unsigned *newSize)
{
  uint32_t localMultipliers[32];
  uint32_t localIndex = 0;

  unsigned c32 = get_local_size(0)/8;
  unsigned cExt = c32 - (32 - 9);

  unsigned i = get_local_id(0);
  unsigned sieveWords = (112*8192)/32;
  for (unsigned extNum = 0; extNum <= cExt; extNum++) {
    __global uint32_t *lPtr = ptr + extNum*sieveWords;
    while (i < sieveWords) {
      uint32_t word = lPtr[i];
      if (word == 0) {
        i += 256;
        continue;
      }

      for (unsigned j = 0; j < c32; j++, word >>= 1) {
        if (word & 0x1) {
          unsigned M = 8*8192*(i*4/8192) + (i*4 + j/8) % 8192 + (j&0x7)*8192;
          localMultipliers[localIndex++] = M << extNum;
        }
      }

      i += 256;
    }

    i = get_local_id(0) + sieveWords / 2;
  }

  multipliersPerThread[get_local_id(0)] = localIndex;
  barrier(CLK_LOCAL_MEM_FENCE);

  unsigned globalIndex = 0;
  for (unsigned i = 0; i < 256; i++)
    globalIndex += ((i < get_local_id(0)) ? multipliersPerThread[i] : 0);

  if (get_local_id(0) == 256 -1)
    *multipliersNum = globalIndex + multipliersPerThread[256 -1];
  barrier(CLK_LOCAL_MEM_FENCE);

  unsigned nonceIdx = sieve->currentNonce;
  uint4 hashl0 = sieve->hash[2*nonceIdx];
  uint4 hashl1 = sieve->hash[2*nonceIdx+1];
  uint32_t nonce = sieve->nonce[nonceIdx];

  uint32_t position = queue->position;
  uint32_t size = queue->size;

  uint4 m0, m1, m2, m3;
  globalIndex += position + size;
  mul256schoolBook_v3(hashl0, hashl1, primorial[0], primorial[1], &m0, &m1, &m2, &m3);
  for (unsigned i = 0; i < localIndex; i++) {
    uint4 chOrl0, chOrl1, chOrl2;
    unsigned bufferIdx = (globalIndex+i) % (16*256);

    mul384_1(m0, m1, m2, localMultipliers[i], &chOrl0, &chOrl1, &chOrl2);
    chOrl0.x += modifier;
    queue->chainOrigins[3*bufferIdx] = chOrl0;
    queue->chainOrigins[3*bufferIdx + 1] = chOrl1;
    queue->chainOrigins[3*bufferIdx + 2] = chOrl2;

    queue->multipliers[bufferIdx] = localMultipliers[i];
    queue->chainLengths[bufferIdx] = 0;
    queue->nonces[bufferIdx] = nonce;
  }

  *newSize = size + *multipliersNum;
  return position;
}





void doFermatTestC12(__global struct GPUNonceAndHash *context,
                     __global struct FermatQueue *groupQueue,
                     __global struct FermatTestResults *groupResults,
                     __global uint32_t *bitfield,
                     __local uint32_t *multipliersPerThread,
                     __local uint8_t *isPrime,
                     __local uint8_t *isResult,
                     __local uint32_t *multipliersNum,
                     __local uint32_t *primesNum,
                     __local uint32_t *resultsNum,
                     __constant uint4 *primorial,
                     unsigned type,
                     unsigned *outputSize)

{
  uint32_t queueSize;
  uint32_t position = extractMultipliers2(context, primorial, bitfield,
                                          multipliersPerThread, multipliersNum,
                                          groupQueue, (type == 1 ? -1 : 1), &queueSize);
  barrier(CLK_GLOBAL_MEM_FENCE);
  while (queueSize >= 256) {
    unsigned bufferIdx = (position + get_local_id(0)) % (16*256) ;
    uint4 chl0 = groupQueue->chainOrigins[3*bufferIdx];
    uint4 chl1 = groupQueue->chainOrigins[3*bufferIdx + 1];
    uint4 chl2 = groupQueue->chainOrigins[3*bufferIdx + 2];
    uint32_t chainLength = groupQueue->chainLengths[bufferIdx];
    uint32_t multiplier = groupQueue->multipliers[bufferIdx];
    uint32_t nonce = groupQueue->nonces[bufferIdx];
    unsigned chainContinue;

    uint4 modpowl0, modpowl1, modpowl2;
    FermatTest384(chl0, chl1, chl2, &modpowl0, &modpowl1, &modpowl2);
    --modpowl0.x;
    modpowl0 |= modpowl1;
    modpowl0 |= modpowl2;
    modpowl0.xy |= modpowl0.zw;
    modpowl0.x |= modpowl0.y;
    chainContinue = !modpowl0.x;

    isPrime[get_local_id(0)] = chainContinue;
    isResult[get_local_id(0)] = !chainContinue && chainLength >= 1;
    barrier(CLK_LOCAL_MEM_FENCE);

    lshift3(&chl0, &chl1, &chl2, 1);
    chl0.x += (type == 1 ? 1 : -1);

    unsigned primeSum = 0, primeIndex;
    unsigned resultSum = 0, resultIndex;
    unsigned threadGrId = get_local_id(0) / 4;
    for (unsigned i = 0; i < 256 / 4; i++) {
      primeSum += ((i < threadGrId) ? ((__local uint32_t*)isPrime)[i] : 0);
      resultSum += ((i < threadGrId) ? ((__local uint32_t*)isResult)[i] : 0);
    }

    primeIndex = (primeSum & 0xFF) + ((primeSum >> 8) & 0xFF) + ((primeSum >> 16) & 0xFF) + (primeSum >> 24);
    primeIndex += (get_local_id(0) % 4 >= 1) ? isPrime[get_local_id(0) - 1] : 0;
    primeIndex += (get_local_id(0) % 4 >= 2) ? isPrime[get_local_id(0) - 2] : 0;
    primeIndex += (get_local_id(0) % 4 >= 3) ? isPrime[get_local_id(0) - 3] : 0;

    resultIndex = (resultSum & 0xFF) + ((resultSum >> 8) & 0xFF) + ((resultSum >> 16) & 0xFF) + (resultSum >> 24);
    resultIndex += (get_local_id(0) % 4 >= 1) ? isResult[get_local_id(0) - 1] : 0;
    resultIndex += (get_local_id(0) % 4 >= 2) ? isResult[get_local_id(0) - 2] : 0;
    resultIndex += (get_local_id(0) % 4 >= 3) ? isResult[get_local_id(0) - 3] : 0;

    if (get_local_id(0) == 256 -1) {
      *primesNum = primeIndex + isPrime[256 -1];
      *resultsNum = resultIndex + isResult[256 -1];
    }
    barrier(CLK_LOCAL_MEM_FENCE);

    if (chainContinue) {
      chainLength++;
      primeIndex = (primeIndex + position + queueSize) % (16*256);
      groupQueue->chainOrigins[3*primeIndex] = chl0;
      groupQueue->chainOrigins[3*primeIndex+1] = chl1;
      groupQueue->chainOrigins[3*primeIndex+2] = chl2;
      groupQueue->chainLengths[primeIndex] = chainLength;
      groupQueue->nonces[primeIndex] = nonce;
      groupQueue->multipliers[primeIndex] = multiplier;
    } else if (chainLength >= 1) {
      resultIndex += *outputSize;
      groupResults->resultTypes[resultIndex] = type;
      groupResults->resultMultipliers[resultIndex] = multiplier;
      groupResults->resultChainLength[resultIndex] = chainLength;
      groupResults->resultNonces[resultIndex] = nonce;
    }

    *outputSize += *resultsNum;
    position += 256;
    queueSize -= (256 - *primesNum);
  }

  groupQueue->position = position % (16*256);
  groupQueue->size = queueSize;
}

unsigned bitwinChainLength(uint32_t C1, uint32_t C2)
{
  return (C1 > C2) ? 2*C2 + 1 : 2*C1;
}

void doFermatTestBt(__global struct GPUNonceAndHash *context,
                    __global struct FermatQueue *groupQueue,
                    __global struct FermatTestResults *groupResults,
                    __global uint32_t *bitfield,
                    __local uint32_t *multipliersPerThread,
                    __local uint8_t *isPrime,
                    __local uint8_t *isResult,
                    __local uint32_t *multipliersNum,
                    __local uint32_t *primesNum,
                    __local uint32_t *resultsNum,
                    __constant uint4 *primorial,
                    unsigned *outputSize)

{
  uint32_t queueSize;
  uint32_t position = extractMultipliers2(context, primorial, bitfield,
                                          multipliersPerThread, multipliersNum,
                                          groupQueue, -1, &queueSize);

  barrier(CLK_GLOBAL_MEM_FENCE);
  while (queueSize >= 256) {
    unsigned bufferIdx = (position + get_local_id(0)) % (16*256);
    uint4 chl0 = groupQueue->chainOrigins[3*bufferIdx];
    uint4 chl1 = groupQueue->chainOrigins[3*bufferIdx + 1];
    uint4 chl2 = groupQueue->chainOrigins[3*bufferIdx + 2];
    uint32_t chainLength = groupQueue->chainLengths[bufferIdx];
    uint32_t multiplier = groupQueue->multipliers[bufferIdx];
    uint32_t nonce = groupQueue->nonces[bufferIdx];
    uint32_t c1ChainLength = chainLength >> 16;

    unsigned chainContinue;
    unsigned usedChainLength;
    unsigned switchedType;

    uint4 modpowl0, modpowl1, modpowl2;
    FermatTest384(chl0, chl1, chl2, &modpowl0, &modpowl1, &modpowl2);
    --modpowl0.x;
    modpowl0 |= modpowl1;
    modpowl0 |= modpowl2;
    modpowl0.xy |= modpowl0.zw;
    modpowl0.x |= modpowl0.y;

    chainContinue = !modpowl0.x ? 1 : (!c1ChainLength && chainLength >= 2);
    switchedType = modpowl0.x ? chainContinue : 0;
    usedChainLength = chainContinue ? 0 : bitwinChainLength(c1ChainLength, chainLength & 0xFFFF);

    isPrime[get_local_id(0)] = chainContinue;
    isResult[get_local_id(0)] = usedChainLength >= 1;
    barrier(CLK_LOCAL_MEM_FENCE);

    if (switchedType) {

      rshift3(&chl0, &chl1, &chl2, chainLength & 0xFF);
      chl0.x += 2;
      chainLength <<= 16;
    } else {
      lshift3(&chl0, &chl1, &chl2, 1);
      chl0.x += !c1ChainLength ? 1 : -1;
      chainLength++;
    }

    unsigned primeSum = 0, primeIndex;
    unsigned resultSum = 0, resultIndex;
    unsigned threadGrId = get_local_id(0) / 4;
    for (unsigned i = 0; i < 256 / 4; i++) {
      primeSum += ((i < threadGrId) ? ((__local uint32_t*)isPrime)[i] : 0);
      resultSum += ((i < threadGrId) ? ((__local uint32_t*)isResult)[i] : 0);
    }

    primeIndex = (primeSum & 0xFF) + ((primeSum >> 8) & 0xFF) + ((primeSum >> 16) & 0xFF) + (primeSum >> 24);
    primeIndex += (get_local_id(0) % 4 >= 1) ? isPrime[get_local_id(0) - 1] : 0;
    primeIndex += (get_local_id(0) % 4 >= 2) ? isPrime[get_local_id(0) - 2] : 0;
    primeIndex += (get_local_id(0) % 4 >= 3) ? isPrime[get_local_id(0) - 3] : 0;

    resultIndex = (resultSum & 0xFF) + ((resultSum >> 8) & 0xFF) + ((resultSum >> 16) & 0xFF) + (resultSum >> 24);
    resultIndex += (get_local_id(0) % 4 >= 1) ? isResult[get_local_id(0) - 1] : 0;
    resultIndex += (get_local_id(0) % 4 >= 2) ? isResult[get_local_id(0) - 2] : 0;
    resultIndex += (get_local_id(0) % 4 >= 3) ? isResult[get_local_id(0) - 3] : 0;

    if (get_local_id(0) == 256 -1) {
      *primesNum = primeIndex + isPrime[256 -1];
      *resultsNum = resultIndex + isResult[256 -1];
    }
    barrier(CLK_LOCAL_MEM_FENCE);

    if (chainContinue) {
      primeIndex = (primeIndex + position + queueSize) % (16*256);
      groupQueue->chainOrigins[3*primeIndex] = chl0;
      groupQueue->chainOrigins[3*primeIndex+1] = chl1;
      groupQueue->chainOrigins[3*primeIndex+2] = chl2;
      groupQueue->chainLengths[primeIndex] = chainLength;
      groupQueue->nonces[primeIndex] = nonce;
      groupQueue->multipliers[primeIndex] = multiplier;
    } else if (usedChainLength >= 1) {
      resultIndex += *outputSize;
      groupResults->resultTypes[resultIndex] = 3;
      groupResults->resultMultipliers[resultIndex] = multiplier;
      groupResults->resultChainLength[resultIndex] = usedChainLength;
      groupResults->resultNonces[resultIndex] = nonce;
    }

    *outputSize += *resultsNum;
    position += 256;
    queueSize -= (256 - *primesNum);
  }

  groupQueue->position = position % (16*256);
  groupQueue->size = queueSize;
}

__kernel void FermatTestEnqueue(__global struct GPUNonceAndHash *nonceAndHash,
                                __constant uint4 *primorial,
                                __global uint32_t *cunningham1Bitfield,
                                __global uint32_t *cunningham2Bitfield,
                                __global uint32_t *bitwinBitfield,
                                __global struct FermatQueue *c1Queue,
                                __global struct FermatQueue *c2Queue,
                                __global struct FermatQueue *btQueue,
                                __global struct FermatTestResults *results)
{
  __global struct GPUNonceAndHash *context = &nonceAndHash[get_group_id(0)];
  __global struct FermatQueue *c1GroupQueue = &c1Queue[get_group_id(0)];
  __global struct FermatQueue *c2GroupQueue = &c2Queue[get_group_id(0)];
  __global struct FermatTestResults *groupResults = &results[get_group_id(0)];
  __global uint32_t *cunningham1Ptr = cunningham1Bitfield + get_group_id(0) * ((8192*(256))*(9 +1))/32;
  __global uint32_t *cunningham2Ptr = cunningham2Bitfield + get_group_id(0) * ((8192*(256))*(9 +1))/32;

  __local uint32_t multipliersPerThread[256];
  __local uint8_t isPrime[256];
  __local uint8_t isResult[256];
  __local uint32_t multipliersNum;
  __local uint32_t primesNum;
  __local uint32_t resultsNum;

  unsigned outputSize = 0;
  doFermatTestC12(context, c1GroupQueue, groupResults, cunningham1Ptr,
                  multipliersPerThread, isPrime, isResult,
                  &multipliersNum, &primesNum, &resultsNum,
                  primorial, 1, &outputSize);

  doFermatTestC12(context, c2GroupQueue, groupResults, cunningham2Ptr,
                  multipliersPerThread, isPrime, isResult,
                  &multipliersNum, &primesNum, &resultsNum,
                  primorial, 2, &outputSize);

  groupResults->size = outputSize;
}

__kernel void FermatTestEnqueueBt(__global struct GPUNonceAndHash *nonceAndHash,
                                  __constant uint4 *primorial,
                                  __global uint32_t *cunningham1Bitfield,
                                  __global uint32_t *cunningham2Bitfield,
                                  __global uint32_t *bitwinBitfield,
                                  __global struct FermatQueue *c1Queue,
                                  __global struct FermatQueue *c2Queue,
                                  __global struct FermatQueue *btQueue,
                                  __global struct FermatTestResults *results)
{
  __global struct GPUNonceAndHash *context = &nonceAndHash[get_group_id(0)];
  __global struct FermatQueue *btGroupQueue = &btQueue[get_group_id(0)];
  __global struct FermatTestResults *groupResults = &results[get_group_id(0)];
  __global uint32_t *bitwinPtr = bitwinBitfield + get_group_id(0) * ((8192*(256))*(9 +1))/32;

  __local uint32_t multipliersPerThread[256];
  __local uint8_t isPrime[256];
  __local uint8_t isResult[256];
  __local uint32_t multipliersNum;
  __local uint32_t primesNum;
  __local uint32_t resultsNum;

  unsigned outputSize = groupResults->size;

  doFermatTestBt(context, btGroupQueue, groupResults, bitwinPtr,
                 multipliersPerThread, isPrime, isResult,
                 &multipliersNum, &primesNum, &resultsNum,
                 primorial, &outputSize);

  groupResults->size = outputSize;
}

__kernel void empty()
{
}
