

// #define STBI_NO_JPEG
// #define STBI_NO_PNG
// #define STBI_NO_BMP
// #define STBI_NO_TGA

#define STBI_NO_PSD
#define STBI_NO_PIC
#define STBI_NO_GIF
#define STBI_NO_HDR
#define STBI_NO_PNM

#define STBI_NO_STDIO

extern void zerog_panic(char const * msg);
#define STBI_ASSERT(_Assertion) do { if((_Assertion) == 0) zerog_panic("Assertion " #_Assertion " failed!");  } while(0)

#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>
