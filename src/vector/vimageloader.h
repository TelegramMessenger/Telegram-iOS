#ifndef VIMAGELOADER_H
#define VIMAGELOADER_H

#include <memory>

#include "vbitmap.h"

class VImageLoader
{
public:
    static VImageLoader& instance()
    {
         static VImageLoader singleton;
         return singleton;
    }

    VBitmap load(const char *fileName);
    ~VImageLoader();
private:
    VImageLoader();
    struct Impl;
    std::unique_ptr<Impl> mImpl;
};

#endif // VIMAGELOADER_H
