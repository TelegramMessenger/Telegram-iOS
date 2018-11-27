#import "FastBlur.h"

#import <Accelerate/Accelerate.h>

static inline uint64_t get_colors (const uint8_t *p) {
    return p[0] + (p[1] << 16) + ((uint64_t)p[2] << 32);
}

void telegramFastBlur(int imageWidth, int imageHeight, int imageStride, void *pixels)
{
    uint8_t *pix = (uint8_t *)pixels;
    const int w = imageWidth;
    const int h = imageHeight;
    const int stride = imageStride;
    const int radius = 3;
    const int r1 = radius + 1;
    const int div = radius * 2 + 1;
    
    if (radius > 15 || div >= w || div >= h)
    {
        return;
    }
    
    uint64_t *rgb = malloc(imageStride * imageHeight * sizeof(uint64_t));
    
    int x, y, i;
    
    int yw = 0;
    const int we = w - r1;
    for (y = 0; y < h; y++) {
        uint64_t cur = get_colors (&pix[yw]);
        uint64_t rgballsum = -radius * cur;
        uint64_t rgbsum = cur * ((r1 * (r1 + 1)) >> 1);
        
        for (i = 1; i <= radius; i++) {
            uint64_t cur = get_colors (&pix[yw + i * 4]);
            rgbsum += cur * (r1 - i);
            rgballsum += cur;
        }
        
        x = 0;
        
#define update(start, middle, end)                         \
rgb[y * w + x] = (rgbsum >> 4) & 0x00FF00FF00FF00FF; \
\
rgballsum += get_colors (&pix[yw + (start) * 4]) -   \
2 * get_colors (&pix[yw + (middle) * 4]) +  \
get_colors (&pix[yw + (end) * 4]);      \
rgbsum += rgballsum;                                 \
x++;                                                 \

        while (x < r1) {
            update (0, x, x + r1);
        }
        while (x < we) {
            update (x - r1, x, x + r1);
        }
        while (x < w) {
            update (x - r1, x, w - 1);
        }
#undef update
        
        yw += stride;
    }
    
    const int he = h - r1;
    for (x = 0; x < w; x++) {
        uint64_t rgballsum = -radius * rgb[x];
        uint64_t rgbsum = rgb[x] * ((r1 * (r1 + 1)) >> 1);
        for (i = 1; i <= radius; i++) {
            rgbsum += rgb[i * w + x] * (r1 - i);
            rgballsum += rgb[i * w + x];
        }
        
        y = 0;
        int yi = x * 4;
        
#define update(start, middle, end)         \
int64_t res = rgbsum >> 4;           \
pix[yi] = (uint8_t)res;                       \
pix[yi + 1] = (uint8_t)(res >> 16);             \
pix[yi + 2] = (uint8_t)(res >> 32);             \
\
rgballsum += rgb[x + (start) * w] -  \
2 * rgb[x + (middle) * w] + \
rgb[x + (end) * w];     \
rgbsum += rgballsum;                 \
y++;                                 \
yi += stride;
        
        while (y < r1) {
            update (0, y, y + r1);
        }
        while (y < he) {
            update (y - r1, y, y + r1);
        }
        while (y < h) {
            update (y - r1, y, h - 1);
        }
#undef update
    }
    
    free(rgb);
}

void telegramFastBlurMore(int imageWidth, int imageHeight, int imageStride, void *pixels)
{
    uint8_t *pix = (uint8_t *)pixels;
    const int w = imageWidth;
    const int h = imageHeight;
    const int stride = imageStride;
    const int radius = 7;
    const int r1 = radius + 1;
    const int div = radius * 2 + 1;
    
    if (radius > 15 || div >= w || div >= h)
    {
        return;
    }
    
    uint64_t *rgb = malloc(imageStride * imageHeight * sizeof(uint64_t));
    
    int x, y, i;
    
    int yw = 0;
    const int we = w - r1;
    for (y = 0; y < h; y++) {
        uint64_t cur = get_colors (&pix[yw]);
        uint64_t rgballsum = -radius * cur;
        uint64_t rgbsum = cur * ((r1 * (r1 + 1)) >> 1);
        
        for (i = 1; i <= radius; i++) {
            uint64_t cur = get_colors (&pix[yw + i * 4]);
            rgbsum += cur * (r1 - i);
            rgballsum += cur;
        }
        
        x = 0;
        
#define update(start, middle, end)                         \
rgb[y * w + x] = (rgbsum >> 6) & 0x00FF00FF00FF00FF; \
\
rgballsum += get_colors (&pix[yw + (start) * 4]) -   \
2 * get_colors (&pix[yw + (middle) * 4]) +  \
get_colors (&pix[yw + (end) * 4]);      \
rgbsum += rgballsum;                                 \
x++;                                                 \

        while (x < r1) {
            update (0, x, x + r1);
        }
        while (x < we) {
            update (x - r1, x, x + r1);
        }
        while (x < w) {
            update (x - r1, x, w - 1);
        }
#undef update
        
        yw += stride;
    }
    
    const int he = h - r1;
    for (x = 0; x < w; x++) {
        uint64_t rgballsum = -radius * rgb[x];
        uint64_t rgbsum = rgb[x] * ((r1 * (r1 + 1)) >> 1);
        for (i = 1; i <= radius; i++) {
            rgbsum += rgb[i * w + x] * (r1 - i);
            rgballsum += rgb[i * w + x];
        }
        
        y = 0;
        int yi = x * 4;
        
#define update(start, middle, end)         \
int64_t res = rgbsum >> 6;           \
pix[yi] = (uint8_t)res;                       \
pix[yi + 1] = (uint8_t)(res >> 16);             \
pix[yi + 2] = (uint8_t)(res >> 32);             \
\
rgballsum += rgb[x + (start) * w] -  \
2 * rgb[x + (middle) * w] + \
rgb[x + (end) * w];     \
rgbsum += rgballsum;                 \
y++;                                 \
yi += stride;
        
        while (y < r1) {
            update (0, y, y + r1);
        }
        while (y < he) {
            update (y - r1, y, y + r1);
        }
        while (y < h) {
            update (y - r1, y, h - 1);
        }
#undef update
    }
    
    free(rgb);
}

void stickerThumbnailAlphaBlur(int imageWidth, int imageHeight, int imageStride, void *pixels) {
    vImage_Buffer srcBuffer;
    srcBuffer.width = imageWidth;
    srcBuffer.height = imageHeight;
    srcBuffer.rowBytes = imageStride;
    srcBuffer.data = pixels;
    
    {
        vImage_Buffer dstBuffer;
        dstBuffer.width = imageWidth;
        dstBuffer.height = imageHeight;
        dstBuffer.rowBytes = imageStride;
        dstBuffer.data = pixels;
        
        int boxSize = 2;
        boxSize = boxSize - (boxSize % 2) + 1;
        
        vImageBoxConvolve_ARGB8888(&srcBuffer, &dstBuffer, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
    }
}
