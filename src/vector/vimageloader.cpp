#include "vimageloader.h"
#include "vdebug.h"
#ifndef WIN32
#include <dlfcn.h>
#else
#include <Windows.h>
#endif
#include <cstring>

using lottie_image_load_f = unsigned char* (*)(const char *filename, int *x, int *y, int *comp, int req_comp);
using lottie_image_load_data_f = unsigned char* (*)(const char  *data, int len, int *x, int *y, int *comp, int req_comp);
using lottie_image_free_f = void (*)(unsigned char *);

struct VImageLoader::Impl
{
#ifdef WIN32
	HMODULE dl_handle{ nullptr };
#else
    void                    *dl_handle{nullptr};
#endif
    lottie_image_load_f      lottie_image_load{nullptr};
    lottie_image_free_f      lottie_image_free{nullptr};
    lottie_image_load_data_f lottie_image_load_data{nullptr};

    Impl()
    {
        #ifdef __APPLE__
            dl_handle = dlopen("librlottie-image-loader.dylib", RTLD_LAZY);
        #elif WIN32
		dl_handle = LoadLibraryA("librlottie-image-loader.dll");
		#else
            dl_handle = dlopen("librlottie-image-loader.so", RTLD_LAZY);
        #endif
        if (!dl_handle)
            vWarning<<"Failed to dlopen librlottie-image-loader library";

#ifdef WIN32
		lottie_image_load = (lottie_image_load_f)GetProcAddress(dl_handle, "lottie_image_load");
#else
		lottie_image_load = (lottie_image_load_f) dlsym(dl_handle, "lottie_image_load");
#endif
		
        if (!lottie_image_load)
            vWarning<<"Failed to find symbol lottie_image_load in librlottie-image-loader library";
#ifdef WIN32
		lottie_image_free = (lottie_image_free_f)GetProcAddress(dl_handle, "lottie_image_free");
#else
        lottie_image_free = (lottie_image_free_f) dlsym(dl_handle, "lottie_image_free");
#endif
        if (!lottie_image_free)
            vWarning<<"Failed to find symbol lottie_image_free in librlottie-image-loader library";
#ifdef WIN32
		lottie_image_load_data = (lottie_image_load_data_f)GetProcAddress(dl_handle, "lottie_image_load_from_data");
#else
        lottie_image_load_data = (lottie_image_load_data_f) dlsym(dl_handle, "lottie_image_load_from_data");
#endif
        if (!lottie_image_load_data)
            vWarning<<"Failed to find symbol lottie_image_load_data in librlottie-image-loader library";
    }
    ~Impl()
    {	
		if (dl_handle)
		{
#ifdef WIN32
		FreeLibrary(dl_handle);
#else
		dlclose(dl_handle); 
#endif
		}
    }

    VBitmap createBitmap(unsigned char *data, int width, int height, int channel)
    {
        // premultiply alpha
        if (channel == 4)
            convertToBGRAPremul(data, width, height);
        else
            convertToBGRA(data, width, height);

        // create a bitmap of same size.
        VBitmap result = VBitmap(width, height, VBitmap::Format::ARGB32_Premultiplied);

        // copy the data to bitmap buffer
        memcpy(result.data(), data, width * height * 4);

        // free the image data
        lottie_image_free(data);

        return result;
    }

    VBitmap load(const char *fileName)
    {
        if (!lottie_image_load) return VBitmap();

        int width, height, n;
        unsigned char *data = lottie_image_load(fileName, &width, &height, &n, 4);

        if (!data) {
            return VBitmap();
        }

        return createBitmap(data, width, height, n);
    }

    VBitmap load(const char *imageData, int len)
    {
        if (!lottie_image_load_data) return VBitmap();

        int width, height, n;
        unsigned char *data = lottie_image_load_data(imageData, len, &width, &height, &n, 4);

        if (!data) {
            return VBitmap();
        }

        return createBitmap(data, width, height, n);
    }
    /*
     * convert from RGBA to BGRA and premultiply
     */
    void convertToBGRAPremul(unsigned char *bits, int width, int height)
    {
        int pixelCount = width * height;
        unsigned char *pix = bits;
        for (int i = 0; i < pixelCount; i++) {
            unsigned char r = pix[0];
            unsigned char g = pix[1];
            unsigned char b = pix[2];
            unsigned char a = pix[3];

            r = (r * a) / 255;
            g = (g * a) / 255;
            b = (b * a) / 255;

            pix[0] = b;
            pix[1] = g;
            pix[2] = r;

            pix += 4;
        }
    }
    /*
     * convert from RGBA to BGRA
     */
    void convertToBGRA(unsigned char *bits, int width, int height)
    {
        int pixelCount = width * height;
        unsigned char *pix = bits;
        for (int i = 0; i < pixelCount; i++) {
            unsigned char r = pix[0];
            unsigned char b = pix[2];
            pix[0] = b;
            pix[2] = r;
            pix += 4;
        }
    }
};

VImageLoader::VImageLoader():
    mImpl(std::make_unique<VImageLoader::Impl>())
{

}

VImageLoader::~VImageLoader() {}

VBitmap VImageLoader::load(const char *fileName)
{
    return mImpl->load(fileName);
}

VBitmap VImageLoader::load(const char *data, int len)
{
    return mImpl->load(data, len);
}

