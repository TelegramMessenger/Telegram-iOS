/*
 * configure stb_image about
 * the image we will support
 */
#define STB_IMAGE_IMPLEMENTATION

#define STBI_ONLY_JPEG
#define STBI_ONLY_PNG
#define STBI_NO_HDR
#define STBI_NO_LINEAR
#define STBI_NO_GIF
#define STBI_NO_PIC

#include "stb_image.h"

#ifdef _WIN32
#ifdef LOT_BUILD
#ifdef DLL_EXPORT
#define LOT_EXPORT __declspec(dllexport)
#else
#define LOT_EXPORT
#endif
#else
#define LOT_EXPORT __declspec(dllimport)
#endif
#else
#ifdef __GNUC__
#if __GNUC__ >= 4
#define LOT_EXPORT __attribute__((visibility("default")))
#else
#define LOT_EXPORT
#endif
#else
#define LOT_EXPORT
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

/*
 * exported function wrapper from the library
 */

LOT_EXPORT unsigned char *lottie_image_load(char const *filename, int *x,
                                            int *y, int *comp, int req_comp)
{
    return stbi_load(filename, x, y, comp, req_comp);
}

LOT_EXPORT unsigned char *lottie_image_load_from_data(const char *imageData,
                                                      int len, int *x, int *y,
                                                      int *comp, int req_comp)
{
    unsigned char *data = (unsigned char *)imageData;
    return stbi_load_from_memory(data, len, x, y, comp, req_comp);
}

LOT_EXPORT void lottie_image_free(unsigned char *data)
{
    stbi_image_free(data);
}

#ifdef __cplusplus
}
#endif
