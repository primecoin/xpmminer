#ifndef __CONFIG_H_
#define __CONFIG_H_

#define IS_BIGENDIAN 0
#define INT128_SIZE 16

#ifdef __cplusplus
inline bool is_bigendian() {
  return IS_BIGENDIAN;
}
#endif  //__cplusplus

/* #undef OS_WINDOWS */
#define OS_LINUX
/* #undef OS_DARWIN */
/* #undef OS_FREEBSD */
#define OS_COMMONUNIX

#define CMAKE_INSTALL_PREFIX "/usr/local"

#endif //__CONFIG_H_
