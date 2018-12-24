#include "vbitmap.h"
#include <string.h>
#include "vglobal.h"

V_BEGIN_NAMESPACE

struct VBitmapData {
    ~VBitmapData();
    VBitmapData();
    static VBitmapData *create(int width, int height, VBitmap::Format format);
    RefCount            ref;
    int                 width;
    int                 height;
    int                 depth;
    int                 stride;
    int                 nBytes;
    VBitmap::Format     format;
    uchar *             data;
    VBitmapCleanupFunction cleanupFunction;
    void *                 cleanupInfo;
    uint                   ownData : 1;
    uint                   roData : 1;
};

VBitmapData::~VBitmapData()
{
    if (cleanupFunction) cleanupFunction(cleanupInfo);
    if (data && ownData) free(data);
    data = 0;
}

VBitmapData::VBitmapData()
    : ref(0),
      width(0),
      height(0),
      depth(0),
      stride(0),
      format(VBitmap::Format::ARGB32),
      data(nullptr),
      cleanupFunction(0),
      cleanupInfo(0),
      ownData(true),
      roData(false)
{
}

VBitmapData *VBitmapData::create(int width, int height, VBitmap::Format format)
{
    if ((width <= 0) || (height <= 0) || format == VBitmap::Format::Invalid)
        return nullptr;

    int depth = 1;
    switch (format) {
    case VBitmap::Format::Alpha8:
        depth = 8;
        VECTOR_FALLTHROUGH
    case VBitmap::Format::ARGB32:
    case VBitmap::Format::ARGB32_Premultiplied:
        depth = 32;
        break;
    default:
        break;
    }

    const int stride = ((width * depth + 31) >> 5)
                       << 2;  // bytes per scanline (must be multiple of 4)

    VBitmapData *d = new VBitmapData;

    d->width = width;
    d->height = height;
    d->depth = depth;
    d->format = format;
    d->stride = stride;
    d->nBytes = d->stride * height;
    d->data = (uchar *)malloc(d->nBytes);

    if (!d->data) {
        delete d;
        return 0;
    }

    return d;
}

inline void VBitmap::cleanUp(VBitmapData *d)
{
    delete d;
}

void VBitmap::detach()
{
    if (d) {
        if (d->ref.isShared() || d->roData) *this = copy();
    }
}

VBitmap::~VBitmap()
{
    if (!d) return;

    if (!d->ref.deref()) cleanUp(d);
}

VBitmap::VBitmap() : d(nullptr) {}

VBitmap::VBitmap(const VBitmap &other)
{
    d = other.d;
    if (d) d->ref.ref();
}

VBitmap::VBitmap(VBitmap &&other) : d(other.d)
{
    other.d = nullptr;
}

VBitmap &VBitmap::operator=(const VBitmap &other)
{
    if (!d) {
        d = other.d;
        if (d) d->ref.ref();
    } else {
        if (!d->ref.deref()) cleanUp(d);
        other.d->ref.ref();
        d = other.d;
    }

    return *this;
}

inline VBitmap &VBitmap::operator=(VBitmap &&other)
{
    if (d && !d->ref.deref()) cleanUp(d);
    d = other.d;
    return *this;
}

VBitmap::VBitmap(int w, int h, VBitmap::Format format) {}
VBitmap::VBitmap(uchar *data, int w, int h, int bytesPerLine,
                 VBitmap::Format format, VBitmapCleanupFunction f,
                 void *cleanupInfo)
{
    d = new VBitmapData;
    d->data = data;
    d->format = format;
    d->width = w;
    d->height = h;
    d->stride = bytesPerLine;
    d->cleanupFunction = nullptr;
    d->cleanupInfo = nullptr;
    d->ownData = false;
    d->roData = false;
    d->ref.setOwned();
}

VBitmap VBitmap::copy(const VRect &r) const
{
    // TODO implement properly.
    return *this;
}

int VBitmap::stride() const
{
    return d ? d->stride : 0;
}

int VBitmap::width() const
{
    return d ? d->width : 0;
}

int VBitmap::height() const
{
    return d ? d->height : 0;
}

uchar *VBitmap::bits()
{
    if (!d) return 0;
    detach();

    // In case detach ran out of memory...
    if (!d) return 0;

    return d->data;
}

const uchar *VBitmap::bits() const
{
    return d ? d->data : 0;
}

bool VBitmap::isNull() const
{
    return !d;
}

uchar *VBitmap::scanLine(int i)
{
    if (!d) return 0;

    detach();

    // In case detach() ran out of memory
    if (!d) return 0;

    return d->data + i * d->stride;
}

const uchar *VBitmap::scanLine(int i) const
{
    if (!d) return 0;

    // assert(i >= 0 && i < height());
    return d->data + i * d->stride;
}

VBitmap::Format VBitmap::format() const
{
    if (!d) return VBitmap::Format::Invalid;
    return d->format;
}

void VBitmap::fill(uint pixel)
{
    if (!d) return;
}

V_END_NAMESPACE
