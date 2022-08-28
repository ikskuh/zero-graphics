#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

extern int zerog_ifloor(double v);
extern int zerog_iceil(double v);
extern double zerog_sqrt(double v);
extern double zerog_pow(double a, double b);
extern double zerog_fmod(double a, double b);
extern double zerog_cos(double v);
extern double zerog_acos(double v);
extern double zerog_fabs(double v);
extern size_t zerog_strlen(char const *str);

extern void *zerog_memcpy(void *dst, void const *src, size_t num);
extern void *zerog_memset(void *ptr, int value, size_t num);

extern void zerog_panic(char const *msg);
extern void *zerog_renderer2d_alloc(void *c_void, size_t size);
extern void zerog_renderer2d_free(void *user_data, void *ptr);

extern int zero_graphics_getDisplayDpi();
extern int zero_graphics_getWidth();
extern int zero_graphics_getHeight();

extern void *zero_graphics_alloc(void *raw_allocator, size_t size);
extern void zero_graphics_writeLog(unsigned int log_level, char const *msg_ptr, size_t length);

#ifdef __cplusplus
}
#endif