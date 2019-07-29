#include "vimageloader.h"
#include "config.h"
#include "vdebug.h"
#ifndef WIN32
#include <dlfcn.h>
#else
#include <Windows.h>
#endif
#include <cstring>

#include "vimageloader.h"

struct VImageLoader::Impl {
};

VImageLoader::VImageLoader() : mImpl(std::make_unique<VImageLoader::Impl>()) {}

VImageLoader::~VImageLoader() {}

VBitmap VImageLoader::load(const char *fileName)
{
    return VBitmap();
}

VBitmap VImageLoader::load(const char *data, int len)
{
    return VBitmap();
}
