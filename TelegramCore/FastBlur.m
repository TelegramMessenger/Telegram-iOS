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

void telegramDspBlur(int imageWidth, int imageHeight, int imageStride, void *pixels) {
    uint8_t *srcData = pixels;
    int bytesPerRow = imageStride;
    int width = imageWidth;
    int height = imageHeight;
    bool shouldClip = false;
    static const float matrix[] = { 1/9.0f, 1/9.0f, 1/9.0f, 1/9.0f, 1/9.0f, 1/9.0f, 1/9.0f, 1/9.0f, 1/9.0f };

//void telegramDspBlur(uint8_t *srcData, int bytesPerRow, int width, int height, float *matrix, int matrixRows, int matrixCols, bool shouldClip) {
    unsigned char *finalData = malloc(bytesPerRow * height * sizeof(unsigned char));
    if (srcData != NULL && finalData != NULL)
    {
        size_t dataSize = bytesPerRow * height;
        // copy src to destination: technically this is a bit wasteful as we'll overwrite
        // all but the "alpha" portion of finalData during processing but I'm unaware of
        // a memcpy with stride function
        memcpy(finalData, srcData, dataSize);
        // alloc space for our dsp arrays
        float *srcAsFloat = malloc(width*height*sizeof(float));
        float *resultAsFloat = malloc(width*height*sizeof(float));
        // loop through each colour (color) chanel (skip the first chanel, it's alpha and is left alone)
        for (int i=1; i<4; i++) {
            // convert src pixels into float data type
            vDSP_vfltu8(srcData+i,4,srcAsFloat,1,width * height);
            // apply matrix using dsp
            /*switch (matrixSize) {
                case DSPMatrixSize3x3:*/
                    vDSP_f3x3(srcAsFloat, height, width, matrix, resultAsFloat);
                    /*break;
                case DSPMatrixSize5x5:
                    vDSP_f5x5(srcAsFloat, height, width, matrix, resultAsFloat);
                    break;
                case DSPMatrixSizeCustom:
                    NSAssert(matrixCols > 0 && matrixRows > 0,
                             @"invalid usage: please use full method definition and pass rows/cols for matrix");
                    vDSP_imgfir(srcAsFloat, height, width, matrix, resultAsFloat, matrixRows, matrixCols);
                    break;
                default:
                    break;
            }*/
            // certain operations may result in values to large or too small in our output float array
            // so if necessary we clip the results here. This param is optional so that we don't need to take
            // the speed hit on blur operations or others which can't result in invalid float values.
            if (shouldClip) {
                float min = 0;
                float max = 255;
                vDSP_vclip(resultAsFloat, 1, &min, &max, resultAsFloat, 1, width * height);
            }
            // convert back into bytes and copy into finalData
            vDSP_vfixu8(resultAsFloat, 1, finalData+i, 4, width * height);
        }
        // clean up dsp space
        free(srcAsFloat);
        free(resultAsFloat);
        memcpy(srcData, finalData, bytesPerRow * height * sizeof(unsigned char));
        free(finalData);
    }
}

