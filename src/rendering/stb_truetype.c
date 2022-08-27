// Include TTF module

#include "../c_interface.h"

// Configure stb_truetype to not depend on *any* libc functions or headers:

#include <stddef.h>

#define STBTT_ifloor(x) zerog_ifloor(x)
#define STBTT_iceil(x) zerog_iceil(x)
#define STBTT_sqrt(x) zerog_sqrt(x)
#define STBTT_pow(x, y) zerog_pow(x, y)
#define STBTT_fmod(x, y) zerog_fmod(x, y)
#define STBTT_cos(x) zerog_cos(x)
#define STBTT_acos(x) zerog_acos(x)
#define STBTT_fabs(x) zerog_fabs(x)
#define STBTT_strlen(x) zerog_strlen(x)
#define STBTT_memcpy(a, b, c) zerog_memcpy(a, b, c)
#define STBTT_memset(a, b, c) zerog_memset(a, b, c)

#define STBTT_malloc(_Size, _UserData) zerog_renderer2d_alloc(_UserData, _Size)
#define STBTT_free(_Ptr, _UserData) zerog_renderer2d_free(_UserData, _Ptr)
#define STBTT_assert(_Assertion)                        \
  do {                                                  \
    if ((_Assertion) == 0)                              \
      zerog_panic("Assertion " #_Assertion " failed!"); \
  } while (0)

#define STB_TRUETYPE_IMPLEMENTATION
#include <stb_truetype.h>
