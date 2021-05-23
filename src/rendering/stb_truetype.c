// Include TTF module

#include <stddef.h>

extern void zerog_panic(char const * msg);

void * zerog_renderer2d_alloc(void * c_void, size_t size);
void zerog_renderer2d_free(void * user_data, void * ptr);

#define STBTT_malloc(_Size, _UserData) zerog_renderer2d_alloc(_UserData, _Size)
#define STBTT_free(_Ptr, _UserData) zerog_renderer2d_free(_UserData, _Ptr)
#define STBTT_assert(_Assertion) do { if((_Assertion) == 0) zerog_panic("Assertion " #_Assertion " failed!");  } while(0)
#define STB_TRUETYPE_IMPLEMENTATION

#include <stb_truetype.h>
