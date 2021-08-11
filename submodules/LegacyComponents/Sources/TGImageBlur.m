#import "TGImageBlur.h"

#import "LegacyComponentsInternal.h"
#import "LegacyComponentsGlobals.h"
#import "TGImageUtils.h"

#import <Accelerate/Accelerate.h>

#import "UIImage+TG.h"
#import "TGStaticBackdropImageData.h"
#import "TGStaticBackdropAreaData.h"

static inline uint64_t get_colors (const uint8_t *p) {
    return p[0] + (p[1] << 16) + ((uint64_t)p[2] << 32);
}

static void fastBlur (int imageWidth, int imageHeight, int imageStride, void *pixels)
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
    
    uint64_t rgb[imageStride * imageHeight];
    
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
}

static void fastBlurMore (int imageWidth, int imageHeight, int imageStride, void *pixels)
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

static void matrixMul(CGFloat *a, CGFloat *b, CGFloat *result)
{
	for (int i = 0; i != 4; ++i)
	{
 		for (int j = 0; j != 4; ++j)
		{
			CGFloat sum = 0;
			for (int k = 0; k != 4; ++k)
			{
				sum += a[i + k * 4] * b[k + j * 4];
			}
			result[i + j * 4] = sum;
		}
	}
}

static inline CGSize fitSize(CGSize size, CGSize maxSize)
{
    if (size.width < 1)
        size.width = 1;
    if (size.height < 1)
        size.height = 1;
    
    if (size.width > maxSize.width)
    {
        size.height = CGFloor((size.height * maxSize.width / size.width));
        size.width = maxSize.width;
    }
    if (size.height > maxSize.height)
    {
        size.width = CGFloor((size.width * maxSize.height / size.height));
        size.height = maxSize.height;
    }
    return size;
}

static void computeImageVariance(uint8_t *memory, int width, int height, int stride, float *outVariance, float *outLuminance, float *outRealLuminance)
{
    uint32_t rnSum = 0;
    uint32_t gnSum = 0;
    uint32_t bnSum = 0;
    
    uint64_t rnSumSq = 0;
    uint64_t gnSumSq = 0;
    uint64_t bnSumSq = 0;
    
    uint32_t luminanceSum = 0;
    //uint64_t luminanceSumSq = 0;
    
    /*float rSum = 0.0f;
    float gSum = 0.0f;
    float bSum = 0.0f;
    
    float rSumSq = 0.0f;
    float gSumSq = 0.0f;
    float bSumSq = 0.0f;*/
    
    uint32_t histogram[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    
    for (int y = 0; y < height; y++)
    {
        for (int x = 0; x < width; x++)
        {
            uint32_t color = *((uint32_t *)&memory[y * stride + x * 4]);
            
            uint32_t r = (color >> 16) & 0xff;
            uint32_t g = (color >> 8) & 0xff;
            uint32_t b = color & 0xff;
            
            uint32_t pixelLuminance = (uint8_t)((r * 299 + g * 587 + b * 114) / 1000);
            histogram[(pixelLuminance * 9 / 255) % 10]++;
            
            luminanceSum += pixelLuminance;
            //luminanceSumSq += pixelLuminance * pixelLuminance;
            
            rnSum += r;
            gnSum += g;
            bnSum += b;
            
            rnSumSq += r * r;
            gnSumSq += g * g;
            bnSumSq += b * b;
            
            /*rSum += r / 255.0f;
            gSum += g / 255.0f;
            bSum += b / 255.0f;
            
            rSumSq += (r / 255.0f) * (r / 255.0f);
            gSumSq += (g / 255.0f) * (g / 255.0f);
            bSumSq += (b / 255.0f) * (b / 255.0f);*/
        }
    }
    
    int n = width * height;
    
    /*float rVariance = (rSumSq - (rSum * rSum) / n) / (n);
    float gVariance = (gSumSq - (gSum * gSum) / n) / (n);
    float bVariance = (bSumSq - (bSum * bSum) / n) / (n);*/
    
    float rnVariance = ((uint64_t)((rnSumSq / 255) - ((uint64_t)rnSum * (uint64_t)rnSum / 255) / n)) / (255.0f * n);
    float gnVariance = ((uint64_t)((gnSumSq / 255) - ((uint64_t)gnSum * (uint64_t)gnSum / 255) / n)) / (255.0f * n);
    float bnVariance = ((uint64_t)((bnSumSq / 255) - ((uint64_t)bnSum * (uint64_t)bnSum / 255) / n)) / (255.0f * n);
    
    float variance = rnVariance + gnVariance + bnVariance;
    if (outVariance != NULL)
        *outVariance = variance;
    
    //float luminanceVariance = ((uint64_t)((luminanceSumSq / 255) - ((uint64_t)luminanceSum * (uint64_t)luminanceSum / 255) / n)) / (255.0f * n);
    
    float floatHistogram[10];
    
    float norm = (float)(width * height);
    
    float n0 = 0.0f;
    float n1 = 0.0f;
    for (int i = 0; i < 10; i++)
    {
        floatHistogram[i] = histogram[i] / norm;
        
        if (i <= 6)
            n0 += floatHistogram[i];
        else
            n1 += floatHistogram[i];
    }
    
    //TGLegacyLog(@"histogram: [%f %f %f %f %f %f %f %f %f %f]", floatHistogram[0], floatHistogram[1], floatHistogram[2], floatHistogram[3], floatHistogram[4], floatHistogram[5], floatHistogram[6], floatHistogram[7], floatHistogram[8], floatHistogram[9]);
    
    if (outLuminance != NULL)
        *outLuminance = n0 < n1 ? 0.95f : 0.5f;
    
    if (outRealLuminance != NULL)
        *outRealLuminance = (luminanceSum / (norm * 255.0f));
}

static void fastScaleImage(uint8_t *sourceMemory, int sourceWidth, int sourceHeight, int sourceStride, uint8_t *targetMemory, int targetWidth, int targetHeight, int targetStride, CGRect sourceRectInTargetSpace)
{
    int imageX = MIN(0, (int)sourceRectInTargetSpace.origin.x);
    int imageY = MIN(0, (int)sourceRectInTargetSpace.origin.y);
    int imageWidth = (int)sourceRectInTargetSpace.size.width;
    int imageHeight = (int)sourceRectInTargetSpace.size.height;
    
    for (int y = 0; y < targetHeight; y++)
    {
        for (int x = 0; x < targetWidth; x++)
        {
            int sourceY = (y - imageY) * sourceHeight / imageHeight;
            int sourceX = (x - imageX) * sourceWidth / imageWidth;
            
            if (sourceX >= 0 && sourceY >= 0 && sourceX < sourceWidth && sourceY < sourceHeight)
            {
                uint32_t color = *((uint32_t *)&sourceMemory[sourceY * sourceStride + sourceX * 4]);
                *((uint32_t *)&targetMemory[y * targetStride + x * 4]) = color;
            }
        }
    }
}

static uint32_t TGImageAverageColor(void *memory, const unsigned int width, const unsigned int height, const unsigned int stride)
{
    int32_t av0 = 0;
    int32_t av1 = 0;
    int32_t av2 = 0;
    
    for (unsigned int y = 0; y < height; y++)
    {
        for (unsigned int x = 0; x < width; x++)
        {
            uint32_t pixel = *((uint32_t *)(&memory[y * stride + x * 4]));
            av0 += pixel & 0xff;
            av1 += (pixel >> 8) & 0xff;
            av2 += (pixel >> 16) & 0xff;
        }
    }
    
    uint32_t norm = (width * height);
    av0 = av0 / norm;
    av1 = av1 / norm;
    av2 = av2 / norm;
    
    return 0xff000000 | av0 | (av1 << 8) | (av2 << 16);
}

static inline uint32_t alphaComposePremultipliedPixels(uint32_t a, uint32_t b)
{
    uint32_t a0 = ((a >> 24) & 0xff);
    uint32_t a1 = ((b >> 24) & 0xff);
    
    uint32_t r0 = (a >> 16) & 0xff;
    uint32_t g0 = (a >> 8) & 0xff;
    uint32_t b0 = a & 0xff;
    
    uint32_t r1 = (b >> 16) & 0xff;
    uint32_t g1 = (b >> 8) & 0xff;
    uint32_t b1 = b & 0xff;
    
    uint32_t ta = ((a0 * a0) >> 8) + ((a1 * (255 - ((a0 * a0) >> 8))) >> 8);
    uint32_t tr = ((r0 * a0) >> 8) + ((r1 * (255 - ((a0 * a0) >> 8))) >> 8);
    uint32_t tg = ((g0 * a0) >> 8) + ((g1 * (255 - ((a0 * a0) >> 8))) >> 8);
    uint32_t tb = ((b0 * a0) >> 8) + ((b1 * (255 - ((a0 * a0) >> 8))) >> 8);
    
    return (ta << 24) | (tr << 16) | (tg << 8) | tb;
}

static inline uint32_t premultipliedPixel(uint32_t rgb, uint32_t alpha)
{
    uint32_t r = (((rgb >> 16) & 0xff) * alpha) >> 8;
    uint32_t g = (((rgb >> 8) & 0xff) * alpha) >> 8;
    uint32_t b = ((rgb & 0xff) * alpha) >> 8;
    
    return (alpha << 24) | (r << 16) | (g << 8) | b;
}

typedef enum {
    TGAttachmentPositionNone = 0,
    TGAttachmentPositionTop = 1 << 0,
    TGAttachmentPositionBottom = 1 << 1,
    TGAttachmentPositionLeft = 1 << 2,
    TGAttachmentPositionRight = 1 << 3,
    TGAttachmentPositionInside = 1 << 4
} TGAttachmentPosition;

static void addAttachmentImageCorners(void *memory, const unsigned int width, const unsigned int height, const unsigned int stride, int position, float fract)
{
    const int scale = (int)TGScreenScaling();
    
    const int shadowSize = 1;
    const int strokeWidth = scale;
    const int smallRadius = floor(3 * scale * fract);
    const int bigRadius = floor(16 * scale * fract);
    
    int topLeftRadius = smallRadius;
    int topRightRadius = smallRadius;
    int bottomLeftRadius = smallRadius;
    int bottomRightRadius = smallRadius;
    
    if (position == TGAttachmentPositionNone)
        topLeftRadius = topRightRadius = bottomLeftRadius = bottomRightRadius = bigRadius;
    else if (position == TGAttachmentPositionInside)
        topLeftRadius = topRightRadius = bottomLeftRadius = bottomRightRadius = smallRadius;
    
    if (position & TGAttachmentPositionTop && position & TGAttachmentPositionLeft)
        topLeftRadius = bigRadius;
    if (position & TGAttachmentPositionTop && position & TGAttachmentPositionRight)
        topRightRadius = bigRadius;
    if (position & TGAttachmentPositionBottom && position & TGAttachmentPositionLeft)
        bottomLeftRadius = bigRadius;
    if (position & TGAttachmentPositionBottom && position & TGAttachmentPositionRight)
        bottomRightRadius = bigRadius;
    
    const int contextWidth = MAX(topLeftRadius, bottomLeftRadius) + MAX(topRightRadius, bottomRightRadius) + shadowSize * 2 + strokeWidth * 2;
    const int contextHeight = MAX(topLeftRadius, topRightRadius) + MAX(bottomLeftRadius, bottomRightRadius) + shadowSize * 2 + strokeWidth * 2;
    const int contextStride = (4 * contextWidth + 15) & (~15);
    
    uint32_t shadowColorRaw = 0x6b86a9c9;
    uint32_t strokeColorArgb = 0xffffffff;
    
    TGImageBorderPallete *pallete = nil;
    if ([[LegacyComponentsGlobals provider] respondsToSelector:@selector(imageBorderPallete)])
        pallete = [[LegacyComponentsGlobals provider] imageBorderPallete];
    
    if (pallete != nil)
    {
        uint32_t strokeColorRaw = TGColorHexCodeWithAlpha(pallete.borderColor);
        strokeColorArgb = premultipliedPixel(strokeColorRaw & 0xffffff, ((strokeColorRaw >> 24) & 0xff));
        shadowColorRaw = TGColorHexCodeWithAlpha(pallete.shadowColor);
    }
    const uint32_t shadowColorArgb = premultipliedPixel(shadowColorRaw & 0xffffff, MAX(0, ((shadowColorRaw >> 24) & 0xff)));
    
    static uint8_t *defaultContextMemory = NULL;
    static uint8_t *defaultAlphaMemory = NULL;
    
    uint8_t *contextMemory = NULL;
    uint8_t *alphaMemory = NULL;

    static uint32_t cachedColor = UINT32_MAX;
    if (position == TGAttachmentPositionNone && (cachedColor == UINT32_MAX || cachedColor == strokeColorArgb))
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            defaultContextMemory = malloc(contextStride * contextHeight);
            memset(defaultContextMemory, 0, contextStride * contextHeight);
            
            defaultAlphaMemory = malloc(contextStride * contextHeight);
            
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
            CGContextRef targetContext = CGBitmapContextCreate(defaultContextMemory, contextWidth, contextHeight, 8, contextStride, colorSpace, bitmapInfo);
            CFRelease(colorSpace);
            
            CGContextSetFillColorWithColor(targetContext, [UIColor blackColor].CGColor);
            CGContextFillEllipseInRect(targetContext, CGRectMake(shadowSize + strokeWidth / 2.0f, shadowSize + strokeWidth / 2.0f, contextWidth - (shadowSize + strokeWidth / 2.0f) * 2.0f, contextHeight - (shadowSize + strokeWidth / 2.0f) * 2.0f));
            
            memcpy(defaultAlphaMemory, defaultContextMemory, contextStride * contextHeight);
            
            memset(defaultContextMemory, 0, contextStride * contextHeight);
            
            CGContextSetStrokeColorWithColor(targetContext, UIColorRGBA(shadowColorRaw, ((shadowColorRaw >> 24) & 0xff) / 255.0f).CGColor);
            CGContextSetLineWidth(targetContext, shadowSize);
            CGContextStrokeEllipseInRect(targetContext, CGRectMake(shadowSize / 2.0f, shadowSize / 2.0f, contextWidth - shadowSize, contextHeight - shadowSize));
            CGContextStrokeEllipseInRect(targetContext, CGRectMake(shadowSize / 2.0f + 0.5f, shadowSize / 2.0f - 0.5f, contextWidth - shadowSize, contextHeight - shadowSize));
            
            CGContextSetStrokeColorWithColor(targetContext, UIColorRGBA(shadowColorRaw, (((shadowColorRaw >> 24) & 0xff) / 255.0f) * 0.5f).CGColor);
            CGContextStrokeEllipseInRect(targetContext, CGRectMake(shadowSize / 2.0f - 0.2f, shadowSize / 2.0f + 0.2f, contextWidth - shadowSize, contextHeight - shadowSize));
            
            CGContextSetStrokeColorWithColor(targetContext, UIColorRGB(strokeColorArgb).CGColor);
            CGContextSetLineWidth(targetContext, strokeWidth);
            CGContextStrokeEllipseInRect(targetContext, CGRectMake(shadowSize + strokeWidth / 2.0f, shadowSize + strokeWidth / 2.0f, contextWidth - (shadowSize + strokeWidth / 2.0f) * 2.0f, contextHeight - (shadowSize + strokeWidth / 2.0f) * 2.0f));
            
            CGContextSetStrokeColorWithColor(targetContext, UIColorRGBA(strokeColorArgb, 0.4f).CGColor);
            CGContextStrokeEllipseInRect(targetContext, CGRectMake(shadowSize + strokeWidth / 2.0f + 0.5f, shadowSize + strokeWidth / 2.0f - 0.5f, contextWidth - (shadowSize + strokeWidth / 2.0f) * 2.0f, contextHeight - (shadowSize + strokeWidth / 2.0f) * 2.0f));
            
            CFRelease(targetContext);
            
            cachedColor = strokeColorArgb;
        });
        
        contextMemory = defaultContextMemory;
        alphaMemory = defaultAlphaMemory;
    }
    else
    {
        contextMemory = malloc(contextStride * contextHeight);
        memset(contextMemory, 0, contextStride * contextHeight);
        
        alphaMemory = malloc(contextStride * contextHeight);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
        CGContextRef targetContext = CGBitmapContextCreate(contextMemory, contextWidth, contextHeight, 8, contextStride, colorSpace, bitmapInfo);
        CFRelease(colorSpace);
        
        void (^drawPie)(CGPoint, CGFloat, CGFloat, CGFloat, bool) = ^(CGPoint center, CGFloat radius, CGFloat start, CGFloat end, bool fill)
        {
            if (fill)
                CGContextMoveToPoint(targetContext, center.x, contextHeight - center.y);
            CGContextAddArc(targetContext, center.x, contextHeight - center.y, radius, start, end, false);
            
            if (fill)
            {
                CGContextFillPath(targetContext);
            }
            else
            {
                CGContextReplacePathWithStrokedPath(targetContext);
                CGContextFillPath(targetContext);
            }
        };
        
        CGFloat (^calcRadius)(CGFloat, CGFloat) = ^CGFloat(CGFloat initialRadius, CGFloat offset)
        {
            return initialRadius + shadowSize + strokeWidth - offset;
        };
        
        void (^draw)(CGFloat, bool) = ^(CGFloat offset, bool fill)
        {
            CGFloat radius = calcRadius(topLeftRadius, offset);
            CGPoint point = CGPointMake(offset + radius, offset + radius);
            drawPie(point, radius, M_PI_2, M_PI, fill);
            
            radius = calcRadius(topRightRadius, offset);
            point = CGPointMake(contextWidth - offset - radius, offset + radius);
            drawPie(point, radius, 0, M_PI_2, fill);

            radius = calcRadius(bottomLeftRadius, offset);
            point = CGPointMake(offset + radius, contextHeight - offset - radius);
            drawPie(point, radius, M_PI, 3 * M_PI_2, fill);

            radius = calcRadius(bottomRightRadius, offset);
            point = CGPointMake(contextWidth - offset - radius, contextHeight - offset - radius);
            drawPie(point, radius, 3 * M_PI_2, 2 * M_PI, fill);
        };
        
        CGContextSetFillColorWithColor(targetContext, [UIColor blackColor].CGColor);
        draw(shadowSize + strokeWidth / 2.0, true);
        
        memcpy(alphaMemory, contextMemory, contextStride * contextHeight);
        
        memset(contextMemory, 0, contextStride * contextHeight);

        CGContextSetFillColorWithColor(targetContext, UIColorRGBA(shadowColorRaw, ((shadowColorRaw >> 24) & 0xff) / 255.0f).CGColor);
        CGContextSetLineWidth(targetContext, shadowSize);
        draw(shadowSize / 2.0f, false);
        draw(shadowSize / 2.0f + 0.5f, false);

        CGContextSetFillColorWithColor(targetContext, UIColorRGBA(shadowColorRaw, (((shadowColorRaw >> 24) & 0xff) / 255.0f) * 0.5f).CGColor);
        draw(shadowSize / 2.0f, false);

        CGContextSetFillColorWithColor(targetContext, UIColorRGB(strokeColorArgb).CGColor);
        CGContextSetLineWidth(targetContext, strokeWidth);
        draw(shadowSize + strokeWidth / 2.0f, false);

        CGContextSetFillColorWithColor(targetContext, UIColorRGBA(strokeColorArgb, 0.4f).CGColor);
        draw(shadowSize + strokeWidth / 2.0f + 0.5f, false);
        
        CFRelease(targetContext);
    }
    
    const unsigned int topLeftRadiusWithPadding = topLeftRadius + shadowSize + strokeWidth;
    for (unsigned int y = 0; y < topLeftRadiusWithPadding; y++)
    {
        for (unsigned int x = 0; x < topLeftRadiusWithPadding; x++)
        {
            uint32_t alpha = alphaMemory[y * contextStride + x * 4 + 3];
            uint32_t pixel = *((uint32_t *)(&memory[y * stride + x * 4]));
            
            pixel = (alpha << 24) | (((((pixel >> 16) & 0xff) * alpha) >> 8) << 16) | (((((pixel >> 8) & 0xff) * alpha) >> 8) << 8) | (((((pixel >> 0) & 0xff) * alpha) >> 8) << 0);
            pixel = alphaComposePremultipliedPixels(*((uint32_t *)&contextMemory[y * contextStride + x * 4]), pixel);
            *((uint32_t *)(&memory[y * stride + x * 4])) = pixel;
        }
    }
    
    const unsigned int topRightRadiusWithPadding = topRightRadius + shadowSize + strokeWidth;
    const unsigned int topRightRadiusOrigin = width - topRightRadiusWithPadding;
    for (int y = 0; y < shadowSize; y++)
    {
        for (unsigned int x = topLeftRadiusWithPadding; x < topRightRadiusOrigin; x++)
        {
            *((uint32_t *)(&memory[y * stride + x * 4])) = shadowColorArgb;
        }
    }
    
    for (int y = shadowSize; y < shadowSize + strokeWidth; y++)
    {
        for (unsigned int x = topLeftRadiusWithPadding; x < topRightRadiusOrigin; x++)
        {
            *((uint32_t *)(&memory[y * stride + x * 4])) = strokeColorArgb;
        }
    }
    
    for (unsigned int y = 0; y < topRightRadiusWithPadding; y++)
    {
        for (unsigned int x = topRightRadiusOrigin; x < width; x++)
        {
            uint32_t alpha = alphaMemory[y * contextStride + ((contextWidth - topRightRadiusWithPadding) + (x - topRightRadiusOrigin)) * 4 + 3];
            uint32_t pixel = *((uint32_t *)(&memory[y * stride + x * 4]));

            pixel = (alpha << 24) | (((((pixel >> 16) & 0xff) * alpha) >> 8) << 16) | (((((pixel >> 8) & 0xff) * alpha) >> 8) << 8) | (((((pixel >> 0) & 0xff) * alpha) >> 8) << 0);
            pixel = alphaComposePremultipliedPixels(*((uint32_t *)&contextMemory[y * contextStride + ((contextWidth - topRightRadiusWithPadding) + (x - topRightRadiusOrigin)) * 4]), pixel);
            *((uint32_t *)(&memory[y * stride + x * 4])) = pixel;
        }
    }
    
    const unsigned int bottomLeftRadiusWithPadding = bottomLeftRadius + shadowSize + strokeWidth;
    const unsigned int bottomLeftRadiusOriginY = height - bottomLeftRadiusWithPadding;
    for (unsigned int y = bottomLeftRadiusOriginY; y < height; y++)
    {
        for (unsigned int x = 0; x < bottomLeftRadiusWithPadding; x++)
        {
            uint32_t alpha = alphaMemory[((contextHeight - bottomLeftRadiusWithPadding) + (y - bottomLeftRadiusOriginY)) * contextStride + x * 4 + 3];
            uint32_t pixel = *((uint32_t *)(&memory[y * stride + x * 4]));
            
            pixel = (alpha << 24) | (((((pixel >> 16) & 0xff) * alpha) >> 8) << 16) | (((((pixel >> 8) & 0xff) * alpha) >> 8) << 8) | (((((pixel >> 0) & 0xff) * alpha) >> 8) << 0);
            pixel = alphaComposePremultipliedPixels(*((uint32_t *)&contextMemory[((contextHeight - bottomLeftRadiusWithPadding) + (y - bottomLeftRadiusOriginY)) * contextStride + x * 4]), pixel);
            *((uint32_t *)(&memory[y * stride + x * 4])) = pixel;
        }
    }
    
    const unsigned int bottomRightRadiusWithPadding = bottomRightRadius + shadowSize + strokeWidth;
    const unsigned int bottomRightRadiusOriginX = width - bottomRightRadiusWithPadding;
    const unsigned int bottomRightRadiusOriginY = height - bottomRightRadiusWithPadding;
    
    for (unsigned int y = topLeftRadiusWithPadding; y < height - bottomLeftRadiusWithPadding; y++)
    {
        for (int x = 0; x < shadowSize; x++)
        {
            *((uint32_t *)(&memory[y * stride + x * 4])) = shadowColorArgb;
        }
        
        for (int x = shadowSize; x < shadowSize + strokeWidth; x++)
        {
            *((uint32_t *)(&memory[y * stride + x * 4])) = strokeColorArgb;
        }
    }
    
    for (unsigned int y = topRightRadiusWithPadding; y < height - bottomRightRadiusWithPadding; y++)
    {
        for (unsigned int x = width - shadowSize - strokeWidth; x < width - shadowSize; x++)
        {
            *((uint32_t *)(&memory[y * stride + x * 4])) = strokeColorArgb;
        }
        
        for (unsigned int x = width - shadowSize; x < width; x++)
        {
            *((uint32_t *)(&memory[y * stride + x * 4])) = shadowColorArgb;
        }
    }
    
    for (unsigned int y = height - shadowSize - strokeWidth; y < height - shadowSize; y++)
    {
        for (unsigned int x = bottomLeftRadiusWithPadding; x < bottomRightRadiusOriginX; x++)
        {
            *((uint32_t *)(&memory[y * stride + x * 4])) = strokeColorArgb;
        }
    }
    
    for (unsigned int y = height - shadowSize; y < height; y++)
    {
        for (unsigned int x = bottomLeftRadiusWithPadding; x < bottomRightRadiusOriginX; x++)
        {
            *((uint32_t *)(&memory[y * stride + x * 4])) = shadowColorArgb;
        }
    }
    
    for (unsigned int y = bottomRightRadiusOriginY; y < height; y++)
    {
        for (unsigned int x = bottomRightRadiusOriginX; x < width; x++)
        {
            uint32_t alpha = alphaMemory[((contextHeight - bottomRightRadiusWithPadding) + (y - bottomRightRadiusOriginY)) * contextStride + ((contextWidth - bottomRightRadiusWithPadding) + (x - bottomRightRadiusOriginX)) * 4 + 3];
            uint32_t pixel = *((uint32_t *)(&memory[y * stride + x * 4]));

            pixel = (alpha << 24) | (((((pixel >> 16) & 0xff) * alpha) >> 8) << 16) | (((((pixel >> 8) & 0xff) * alpha) >> 8) << 8) | (((((pixel >> 0) & 0xff) * alpha) >> 8) << 0);
            pixel = alphaComposePremultipliedPixels(*((uint32_t *)&contextMemory[((contextHeight - bottomRightRadiusWithPadding) + (y - bottomRightRadiusOriginY)) * contextStride + ((contextWidth - bottomRightRadiusWithPadding) + (x - bottomRightRadiusOriginX)) * 4]), pixel);
            *((uint32_t *)(&memory[y * stride + x * 4])) = pixel;
        }
    }
    
    if (contextMemory != defaultContextMemory)
    {
        free(contextMemory);
        free(alphaMemory);
    }
}

void TGAddImageCorners(void *memory, const unsigned int width, const unsigned int height, const unsigned int stride, int radius, int position)
{
    const int scale = TGScreenScaling();
    
    const int smallRadius = 3 * scale;
    const int bigRadius = radius * scale;
    
    int topLeftRadius = smallRadius;
    int topRightRadius = smallRadius;
    int bottomLeftRadius = smallRadius;
    int bottomRightRadius = smallRadius;
    
    if (position == TGAttachmentPositionNone)
        topLeftRadius = topRightRadius = bottomLeftRadius = bottomRightRadius = bigRadius;
    else if (position == TGAttachmentPositionInside)
        topLeftRadius = topRightRadius = bottomLeftRadius = bottomRightRadius = smallRadius;
    
    if (position & TGAttachmentPositionTop && position & TGAttachmentPositionLeft)
        topLeftRadius = bigRadius;
    if (position & TGAttachmentPositionTop && position & TGAttachmentPositionRight)
        topRightRadius = bigRadius;
    if (position & TGAttachmentPositionBottom && position & TGAttachmentPositionLeft)
        bottomLeftRadius = bigRadius;
    if (position & TGAttachmentPositionBottom && position & TGAttachmentPositionRight)
        bottomRightRadius = bigRadius;
    
    const int contextWidth = MAX(topLeftRadius, bottomLeftRadius) + MAX(topRightRadius, bottomRightRadius);
    const int contextHeight = MAX(topLeftRadius, topRightRadius) + MAX(bottomLeftRadius, bottomRightRadius);
    const int contextStride = (4 * contextWidth + 15) & (~15);
    
    if (radius <= 0 || contextWidth > width || contextHeight > height) {
        return;
    }
    
    uint8_t *contextMemory = NULL;
    uint8_t *alphaMemory = NULL;
    
    {        
        contextMemory = malloc(contextStride * contextHeight);
        memset(contextMemory, 0, contextStride * contextHeight);
        
        alphaMemory = malloc(contextStride * contextHeight);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
        CGContextRef targetContext = CGBitmapContextCreate(contextMemory, contextWidth, contextHeight, 8, contextStride, colorSpace, bitmapInfo);
        CFRelease(colorSpace);
        
        void (^drawPie)(CGPoint, CGFloat, CGFloat, CGFloat, bool) = ^(CGPoint center, CGFloat radius, CGFloat start, CGFloat end, bool fill)
        {
            if (fill)
                CGContextMoveToPoint(targetContext, center.x, contextHeight - center.y);
            CGContextAddArc(targetContext, center.x, contextHeight - center.y, radius, start, end, false);
            
            if (fill)
            {
                CGContextFillPath(targetContext);
            }
            else
            {
                CGContextReplacePathWithStrokedPath(targetContext);
                CGContextFillPath(targetContext);
            }
        };
        
        CGFloat (^calcRadius)(CGFloat, CGFloat) = ^CGFloat(CGFloat initialRadius, CGFloat offset)
        {
            return initialRadius - offset;
        };
        
        void (^draw)(CGFloat, bool) = ^(CGFloat offset, bool fill)
        {
            CGFloat radius = calcRadius(topLeftRadius, offset);
            CGPoint point = CGPointMake(offset + radius, offset + radius);
            drawPie(point, radius, M_PI_2, M_PI, fill);
            
            radius = calcRadius(topRightRadius, offset);
            point = CGPointMake(contextWidth - offset - radius, offset + radius);
            drawPie(point, radius, 0, M_PI_2, fill);
            
            radius = calcRadius(bottomLeftRadius, offset);
            point = CGPointMake(offset + radius, contextHeight - offset - radius);
            drawPie(point, radius, M_PI, 3 * M_PI_2, fill);
            
            radius = calcRadius(bottomRightRadius, offset);
            point = CGPointMake(contextWidth - offset - radius, contextHeight - offset - radius);
            drawPie(point, radius, 3 * M_PI_2, 2 * M_PI, fill);
        };
        
        CGContextSetFillColorWithColor(targetContext, [UIColor blackColor].CGColor);
        draw(0.0f, true);
        
        memcpy(alphaMemory, contextMemory, contextStride * contextHeight);
        
        memset(contextMemory, 0, contextStride * contextHeight);

        CFRelease(targetContext);
    }
    
    const unsigned int topLeftRadiusWithPadding = topLeftRadius;
    for (unsigned int y = 0; y < topLeftRadiusWithPadding; y++)
    {
        for (unsigned int x = 0; x < topLeftRadiusWithPadding; x++)
        {
            uint32_t alpha = alphaMemory[y * contextStride + x * 4 + 3];
            uint32_t pixel = *((uint32_t *)(&memory[y * stride + x * 4]));
            
            pixel = (alpha << 24) | (((((pixel >> 16) & 0xff) * alpha) >> 8) << 16) | (((((pixel >> 8) & 0xff) * alpha) >> 8) << 8) | (((((pixel >> 0) & 0xff) * alpha) >> 8) << 0);
            pixel = alphaComposePremultipliedPixels(*((uint32_t *)&contextMemory[y * contextStride + x * 4]), pixel);
            *((uint32_t *)(&memory[y * stride + x * 4])) = pixel;
        }
    }
    
    const unsigned int topRightRadiusWithPadding = topRightRadius;
    const unsigned int topRightRadiusOrigin = width - topRightRadiusWithPadding;
    
    for (unsigned int y = 0; y < topRightRadiusWithPadding; y++)
    {
        for (unsigned int x = topRightRadiusOrigin; x < width; x++)
        {
            uint32_t alpha = alphaMemory[y * contextStride + ((contextWidth - topRightRadiusWithPadding) + (x - topRightRadiusOrigin)) * 4 + 3];
            uint32_t pixel = *((uint32_t *)(&memory[y * stride + x * 4]));
            
            pixel = (alpha << 24) | (((((pixel >> 16) & 0xff) * alpha) >> 8) << 16) | (((((pixel >> 8) & 0xff) * alpha) >> 8) << 8) | (((((pixel >> 0) & 0xff) * alpha) >> 8) << 0);
            pixel = alphaComposePremultipliedPixels(*((uint32_t *)&contextMemory[y * contextStride + ((contextWidth - topRightRadiusWithPadding) + (x - topRightRadiusOrigin)) * 4]), pixel);
            *((uint32_t *)(&memory[y * stride + x * 4])) = pixel;
        }
    }
    
    const unsigned int bottomLeftRadiusWithPadding = bottomLeftRadius;
    const unsigned int bottomLeftRadiusOriginY = height - bottomLeftRadiusWithPadding;
    for (unsigned int y = bottomLeftRadiusOriginY; y < height; y++)
    {
        for (unsigned int x = 0; x < bottomLeftRadiusWithPadding; x++)
        {
            uint32_t alpha = alphaMemory[((contextHeight - bottomLeftRadiusWithPadding) + (y - bottomLeftRadiusOriginY)) * contextStride + x * 4 + 3];
            uint32_t pixel = *((uint32_t *)(&memory[y * stride + x * 4]));
            
            pixel = (alpha << 24) | (((((pixel >> 16) & 0xff) * alpha) >> 8) << 16) | (((((pixel >> 8) & 0xff) * alpha) >> 8) << 8) | (((((pixel >> 0) & 0xff) * alpha) >> 8) << 0);
            pixel = alphaComposePremultipliedPixels(*((uint32_t *)&contextMemory[((contextHeight - bottomLeftRadiusWithPadding) + (y - bottomLeftRadiusOriginY)) * contextStride + x * 4]), pixel);
            *((uint32_t *)(&memory[y * stride + x * 4])) = pixel;
        }
    }
    
    const unsigned int bottomRightRadiusWithPadding = bottomRightRadius;
    const unsigned int bottomRightRadiusOriginX = width - bottomRightRadiusWithPadding;
    const unsigned int bottomRightRadiusOriginY = height - bottomRightRadiusWithPadding;
    for (unsigned int y = bottomRightRadiusOriginY; y < height; y++)
    {
        for (unsigned int x = bottomRightRadiusOriginX; x < width; x++)
        {
            uint32_t alpha = alphaMemory[((contextHeight - bottomRightRadiusWithPadding) + (y - bottomRightRadiusOriginY)) * contextStride + ((contextWidth - bottomRightRadiusWithPadding) + (x - bottomRightRadiusOriginX)) * 4 + 3];
            uint32_t pixel = *((uint32_t *)(&memory[y * stride + x * 4]));
            
            pixel = (alpha << 24) | (((((pixel >> 16) & 0xff) * alpha) >> 8) << 16) | (((((pixel >> 8) & 0xff) * alpha) >> 8) << 8) | (((((pixel >> 0) & 0xff) * alpha) >> 8) << 0);
            pixel = alphaComposePremultipliedPixels(*((uint32_t *)&contextMemory[((contextHeight - bottomRightRadiusWithPadding) + (y - bottomRightRadiusOriginY)) * contextStride + ((contextWidth - bottomRightRadiusWithPadding) + (x - bottomRightRadiusOriginX)) * 4]), pixel);
            *((uint32_t *)(&memory[y * stride + x * 4])) = pixel;
        }
    }
    
    free(alphaMemory);
    free(contextMemory);
}

static int16_t *brightenMatrix(int32_t *outDivisor)
{
    static int16_t saturationMatrix[16];
    static const int32_t divisor = 256;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGFloat s = 2.6f;
        CGFloat offset = 0.02f;
        CGFloat factor = 1.3f;
        CGFloat satMatrix[] = {
            0.0722f + 0.9278f * s,  0.0722f - 0.0722f * s,  0.0722f - 0.0722f * s,  0,
            0.7152f - 0.7152f * s,  0.7152f + 0.2848f * s,  0.7152f - 0.7152f * s,  0,
            0.2126f - 0.2126f * s,  0.2126f - 0.2126f * s,  0.2126f + 0.7873f * s,  0,
            0.0f,                    0.0f,                    0.0f,  1,
        };
        CGFloat contrastMatrix[] = {
            factor, 0.0f, 0.0f, 0.0f,
            0.0f, factor, 0.0f, 0.0f,
            0.0f, 0.0f, factor, 0.0f,
            offset, offset, offset, 1.0f
        };
        CGFloat colorMatrix[16];
        matrixMul(satMatrix, contrastMatrix, colorMatrix);
        
        NSUInteger matrixSize = sizeof(colorMatrix) / sizeof(colorMatrix[0]);
        for (NSUInteger i = 0; i < matrixSize; ++i) {
            saturationMatrix[i] = (int16_t)CGRound(colorMatrix[i] * divisor);
        }
    });
    
    if (outDivisor != NULL)
        *outDivisor = divisor;
    
    return saturationMatrix;
}

static int16_t *lightBrightenMatrix(int32_t *outDivisor)
{
    static int16_t saturationMatrix[16];
    static const int32_t divisor = 256;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGFloat s = 1.8f;
        CGFloat offset = 0.02f;
        CGFloat factor = 1.1f;
        CGFloat satMatrix[] = {
            0.0722f + 0.9278f * s,  0.0722f - 0.0722f * s,  0.0722f - 0.0722f * s,  0,
            0.7152f - 0.7152f * s,  0.7152f + 0.2848f * s,  0.7152f - 0.7152f * s,  0,
            0.2126f - 0.2126f * s,  0.2126f - 0.2126f * s,  0.2126f + 0.7873f * s,  0,
            0.0f,                    0.0f,                    0.0f,  1,
        };
        CGFloat contrastMatrix[] = {
            factor, 0.0f, 0.0f, 0.0f,
            0.0f, factor, 0.0f, 0.0f,
            0.0f, 0.0f, factor, 0.0f,
            offset, offset, offset, 1.0f
        };
        CGFloat colorMatrix[16];
        matrixMul(satMatrix, contrastMatrix, colorMatrix);
        
        NSUInteger matrixSize = sizeof(colorMatrix) / sizeof(colorMatrix[0]);
        for (NSUInteger i = 0; i < matrixSize; ++i) {
            saturationMatrix[i] = (int16_t)CGRound(colorMatrix[i] * divisor);
        }
    });
    
    if (outDivisor != NULL)
        *outDivisor = divisor;
    
    return saturationMatrix;
}

static int16_t *secretMatrix(int32_t *outDivisor)
{
    static int16_t saturationMatrix[16];
    static const int32_t divisor = 256;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGFloat s = 1.6f;
        CGFloat offset = 0.0f;
        CGFloat factor = 1.3f;
        CGFloat satMatrix[] = {
            0.0722f + 0.9278f * s,  0.0722f - 0.0722f * s,  0.0722f - 0.0722f * s,  0,
            0.7152f - 0.7152f * s,  0.7152f + 0.2848f * s,  0.7152f - 0.7152f * s,  0,
            0.2126f - 0.2126f * s,  0.2126f - 0.2126f * s,  0.2126f + 0.7873f * s,  0,
            0.0f,                    0.0f,                    0.0f,  1,
        };
        CGFloat contrastMatrix[] = {
            factor, 0.0f, 0.0f, 0.0f,
            0.0f, factor, 0.0f, 0.0f,
            0.0f, 0.0f, factor, 0.0f,
            offset, offset, offset, 1.0f
        };
        CGFloat colorMatrix[16];
        matrixMul(satMatrix, contrastMatrix, colorMatrix);
        
        NSUInteger matrixSize = sizeof(colorMatrix) / sizeof(colorMatrix[0]);
        for (NSUInteger i = 0; i < matrixSize; ++i) {
            saturationMatrix[i] = (int16_t)CGRound(colorMatrix[i] * divisor);
        }
    });
    
    if (outDivisor != NULL)
        *outDivisor = divisor;
    
    return saturationMatrix;
}

UIImage *TGAverageColorImage(UIColor *color)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 1.0f), true, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, 1.0f, 1.0f));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

UIImage *TGAverageColorRoundImage(UIColor *color, CGSize size)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size.width, size.height), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, 1.0f, 1.0f));
    CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

UIImage *TGAverageColorAttachmentImage(UIColor *color, bool attachmentBorder, int position)
{
    return TGAverageColorAttachmentWithCornerRadiusImage(color, attachmentBorder, 13, position);
}

UIImage *TGAverageColorAttachmentWithCornerRadiusImage(UIColor *color, bool attachmentBorder, int cornerRadius, int position)
{
    CGFloat scale = TGScreenScaling();
    
    CGSize size = CGSizeMake(36.0f, 36.0f);
    if (cornerRadius > size.width / 2)
        size = CGSizeMake(cornerRadius * 2, cornerRadius * 2);
    
    const struct { int width, height; } targetContextSize = { (int)(size.width * scale), (int)(size.height * scale)};
    
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    UIGraphicsPushContext(targetContext);
    CGContextTranslateCTM(targetContext, targetContextSize.width / 2.0f, targetContextSize.height / 2.0f);
    CGContextScaleCTM(targetContext, 1.0f, -1.0f);
    CGContextTranslateCTM(targetContext, -targetContextSize.width / 2.0f, -targetContextSize.height / 2.0f);
    CGContextScaleCTM(targetContext, scale, scale);
    
    CGColorSpaceRelease(colorSpace);
    
    CGContextSetBlendMode(targetContext, kCGBlendModeCopy);
    
    CGContextSetFillColorWithColor(targetContext, [color CGColor]);
    CGContextFillRect(targetContext, CGRectMake(0.0f, 0.0f, targetContextSize.width, targetContextSize.height));
    
    if (attachmentBorder) {
        addAttachmentImageCorners(targetMemory, targetContextSize.width, targetContextSize.height, (unsigned int)targetBytesPerRow, position, 1.0f);
    }
    else if (cornerRadius > 0) {
        TGAddImageCorners(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, cornerRadius, position);
    }
    
    UIGraphicsPopContext();
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[[UIImage alloc] initWithCGImage:bitmapImage scale:scale orientation:UIImageOrientationUp] stretchableImageWithLeftCapWidth:(int)(targetContextSize.width / scale / 2) topCapHeight:(int)(targetContextSize.height / scale / 2)];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    /*CGFloat matrix[16];
    int32_t divisor = 256;
    int16_t *integerMatrix = brightenMatrix(&divisor);
    
    for (int i = 0; i < 16; i++)
    {
        matrix[i] = integerMatrix[i] / (CGFloat)divisor;
    }
    
    CGFloat vector[4];
    [color getRed:&vector[3] green:&vector[2] blue:&vector[1] alpha:&vector[0]];
    
    CGFloat resultColor[4];
    matrixVectorMul(matrix, vector, resultColor);
    
    UIImage *genericCircleImage = nil;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(50.0f, 50.0f), false, scale);
    CGContextRef circleContext = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(circleContext, [[UIColor alloc] initWithRed:vector[3] green:vector[2] blue:vector[1] alpha:vector[0]].CGColor);
    CGContextFillEllipseInRect(circleContext, CGRectMake(0.0f, 0.0f, 50.0f, 50.0f));
    genericCircleImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [image setActionCircleImage:genericCircleImage];*/
    
    return image;
}

static void modifyAndBlurImage(void *pixels, unsigned int width, unsigned int height, unsigned int stride, bool strongBlur, int16_t *matrix)
{
    unsigned int tempWidth = width / 6;
    unsigned int tempHeight = height / 6;
    unsigned int tempStride = ((4 * tempWidth + 15) & (~15));
    void *tempPixels = malloc(tempStride * tempHeight);
    
    vImage_Buffer srcBuffer;
    srcBuffer.width = width;
    srcBuffer.height = height;
    srcBuffer.rowBytes = stride;
    srcBuffer.data = pixels;
    
    vImage_Buffer dstBuffer;
    dstBuffer.width = tempWidth;
    dstBuffer.height = tempHeight;
    dstBuffer.rowBytes = tempStride;
    dstBuffer.data = tempPixels;
    
    vImageScale_ARGB8888(&srcBuffer, &dstBuffer, NULL, kvImageDoNotTile);
    
    fastBlurMore(tempWidth, tempHeight, tempStride, tempPixels);
    if (strongBlur)
        fastBlur(tempWidth, tempHeight, tempStride, tempPixels);
    
    int32_t divisor = 256;
    vImageMatrixMultiply_ARGB8888(&dstBuffer, &dstBuffer, matrix, divisor, NULL, NULL, kvImageDoNotTile);
    vImageScale_ARGB8888(&dstBuffer, &srcBuffer, NULL, kvImageDoNotTile);
    
    free(tempPixels);
}

static void modifyImage(void *pixels, unsigned int width, unsigned int height, unsigned int stride, int16_t *matrix)
{
    vImage_Buffer dstBuffer;
    dstBuffer.width = width;
    dstBuffer.height = height;
    dstBuffer.rowBytes = stride;
    dstBuffer.data = pixels;
    
    int32_t divisor = 256;
    vImageMatrixMultiply_ARGB8888(&dstBuffer, &dstBuffer, matrix, divisor, NULL, NULL, kvImageDoNotTile);
}

static void brightenAndBlurImage(void *pixels, unsigned int width, unsigned int height, unsigned int stride, bool strongBlur)
{
    modifyAndBlurImage(pixels, width, height, stride, strongBlur, brightenMatrix(NULL));
}

static void brightenImage(void *pixels, unsigned int width, unsigned int height, unsigned int stride)
{
    modifyImage(pixels, width, height, stride, lightBrightenMatrix(NULL));
}

TGStaticBackdropAreaData *createImageBackdropArea(uint8_t *sourceImageMemory, int sourceImageWidth, int sourceImageHeight, int sourceImageStride, CGSize originalSize, CGRect sourceImageRect)
{
    CGFloat scale = TGIsRetina() ? 2.0f : 1.0f;
    
    const struct { int width, height; } contextSize = { (int)(sourceImageRect.size.width / 2), (int)(sourceImageRect.size.height / 2) };
    size_t bytesPerRow = ((4 * (int)contextSize.width) + 15) & (~15);
    
    CGFloat scalingFactor = contextSize.width / sourceImageRect.size.width;
    
    void *memory = malloc((int)(bytesPerRow * contextSize.height));
    memset(memory, 0x00, (int)(bytesPerRow * contextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    CGContextRef context = CGBitmapContextCreate(memory, (int)contextSize.width, (int)contextSize.height, 8, bytesPerRow, colorSpace, bitmapInfo);
    CGColorSpaceRelease(colorSpace);
    UIGraphicsPushContext(context);
    
    CGContextTranslateCTM(context, contextSize.width / 2.0f, contextSize.height / 2.0f);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGContextTranslateCTM(context, -contextSize.width / 2.0f, -contextSize.height / 2.0f);
    
    CGRect imageRect = CGRectMake(-sourceImageRect.origin.x * scalingFactor, -sourceImageRect.origin.y * scalingFactor, originalSize.width * scalingFactor, originalSize.height * scalingFactor);
    
    float luminance = 0.0f;
    float realLuminance = 0.0f;
    float variance = 0.0f;
    
    if (sourceImageMemory != NULL)
    {
        fastScaleImage(sourceImageMemory, sourceImageWidth, sourceImageHeight, sourceImageStride, memory, contextSize.width, contextSize.height, (int)bytesPerRow, imageRect);
    }
    
    /*if (luminance > 0.8f)
        modifyAndBlurImage(memory, contextSize.width, contextSize.height, bytesPerRow, false, brightenTimestampMatrix(NULL));
    else
        modifyAndBlurImage(memory, contextSize.width, contextSize.height, bytesPerRow, false, darkenTimestampMatrix(NULL));*/
    
    fastBlur(contextSize.width, contextSize.height, (int)bytesPerRow, memory);
    fastBlur(contextSize.width, contextSize.height, (int)bytesPerRow, memory);
    computeImageVariance(memory, contextSize.width, contextSize.height, (int)bytesPerRow, &variance, &luminance, &realLuminance);
    
    if ((variance >= 0.009f && realLuminance > 0.7f) || variance >= 0.05f)
    {
        uint32_t color = TGImageAverageColor(memory, contextSize.width, contextSize.height, (int)bytesPerRow);
        //color = 0xff00ffff;
        CGContextSetFillColorWithColor(context, UIColorRGBA(color, 0.7f).CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, contextSize.width, contextSize.height));
        
        uint32_t r = (color >> 16) & 0xff;
        uint32_t g = (color >> 8) & 0xff;
        uint32_t b = color & 0xff;
        
        uint32_t pixelLuminance = (uint8_t)((r * 299 + g * 587 + b * 114) / 1000);
        luminance = pixelLuminance / 255.0f;
        if (luminance < 0.85f)
            luminance = 0.0f;
    }
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(context);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(bitmapImage);
    
    UIGraphicsPopContext();
    CFRelease(context);
    free(memory);
    
    TGStaticBackdropAreaData *backdropArea = [[TGStaticBackdropAreaData alloc] initWithBackground:image mappedRect:CGRectMake(sourceImageRect.origin.x / originalSize.width, sourceImageRect.origin.y / originalSize.height, sourceImageRect.size.width / originalSize.width, sourceImageRect.size.height / originalSize.height)];
    backdropArea.luminance = luminance;
    
    return backdropArea;
}

TGStaticBackdropAreaData *createTimestampBackdropArea(uint8_t *sourceImageMemory, int sourceImageWidth, int sourceImageHeight, int sourceImageStride, CGSize originalSize)
{
    const int extraRadius = 0.0f;
    const struct { int width, height; } unscaledSize = { 84 + extraRadius * 2, 18 };
    const struct { int right, bottom; } padding = { 6 - extraRadius, 6 };

    return createImageBackdropArea(sourceImageMemory, sourceImageWidth, sourceImageHeight, sourceImageStride, originalSize, CGRectMake(originalSize.width - padding.right - unscaledSize.width, originalSize.height - padding.bottom - unscaledSize.height, unscaledSize.width, unscaledSize.height));
}

TGStaticBackdropAreaData *createAdditionalDataBackdropArea(uint8_t *sourceImageMemory, int sourceImageWidth, int sourceImageHeight, int sourceImageStride, CGSize originalSize)
{
    const int extraRadius = 0.0f;
    const struct { int width, height; } unscaledSize = { 160 + extraRadius * 2, 18 };
    const struct { int left, top; } padding = { 6 - extraRadius, 6 };
    
    return createImageBackdropArea(sourceImageMemory, sourceImageWidth, sourceImageHeight, sourceImageStride, originalSize, CGRectMake(padding.left, padding.top, unscaledSize.width, unscaledSize.height));
}

UIImage *TGBlurredAttachmentImage(UIImage *source, CGSize size, uint32_t *averageColor, bool attachmentBorder, int position)
{
    return TGBlurredAttachmentWithCornerRadiusImage(source, size, averageColor, attachmentBorder, attachmentBorder ? 14 : 15, position);
}

UIImage *TGBlurredAttachmentWithCornerRadiusImage(UIImage *source, CGSize size, uint32_t *averageColor, bool attachmentBorder, int cornerRadius, int position)
{
    CGFloat scale = TGScreenScaling(); // //TGIsRetina() ? 2.0f : 1.0f;
    
    CGSize fittedSize = fitSize(size, CGSizeMake(90, 90));
    
    CGFloat actionCircleDiameter = 50.0f;
    
    const struct { int width, height; } blurredContextSize = { (int)fittedSize.width, (int)fittedSize.height };
    const struct { int width, height; } targetContextSize = { (int)(size.width * scale), (int)(size.height * scale)};
    const struct { int width, height; } actionCircleContextSize = { (int)(actionCircleDiameter * scale), (int)(actionCircleDiameter * scale) };
    
    size_t blurredBytesPerRow = ((4 * (int)blurredContextSize.width) + 15) & (~15);
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    size_t actionCircleBytesPerRow = ((4 * (int)actionCircleContextSize.width) + 15) & (~15);
    
    void *blurredMemory = malloc((int)(blurredBytesPerRow * blurredContextSize.height));
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    void *actionCircleMemory = malloc(((int)(actionCircleBytesPerRow * actionCircleContextSize.height)));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef blurredContext = CGBitmapContextCreate(blurredMemory, (int)blurredContextSize.width, (int)blurredContextSize.height, 8, blurredBytesPerRow, colorSpace, bitmapInfo);
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    CGContextRef actionCircleContext = CGBitmapContextCreate(actionCircleMemory, (int)actionCircleContextSize.width, (int)actionCircleContextSize.height, 8, actionCircleBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(blurredContext);
    CGContextTranslateCTM(blurredContext, blurredContextSize.width / 2.0f, blurredContextSize.height / 2.0f);
    CGContextScaleCTM(blurredContext, 1.0f, -1.0f);
    CGContextTranslateCTM(blurredContext, -blurredContextSize.width / 2.0f, -blurredContextSize.height / 2.0f);
    CGContextSetInterpolationQuality(blurredContext, kCGInterpolationLow);
    [source drawInRect:CGRectMake(0, 0, blurredContextSize.width, blurredContextSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    fastBlur((int)blurredContextSize.width, (int)blurredContextSize.height, (int)blurredBytesPerRow, blurredMemory);
    
    if (averageColor != NULL)
    {
        *averageColor = TGImageAverageColor(blurredMemory, blurredContextSize.width, blurredContextSize.height, (int)blurredBytesPerRow);
    }
    
    vImage_Buffer srcBuffer;
    srcBuffer.width = blurredContextSize.width;
    srcBuffer.height = blurredContextSize.height;
    srcBuffer.rowBytes = blurredBytesPerRow;
    srcBuffer.data = blurredMemory;
    
    vImage_Buffer dstBuffer;
    dstBuffer.width = targetContextSize.width;
    dstBuffer.height = targetContextSize.height;
    dstBuffer.rowBytes = targetBytesPerRow;
    dstBuffer.data = targetMemory;
    
    vImageScale_ARGB8888(&srcBuffer, &dstBuffer, NULL, kvImageDoNotTile);
    
    CGContextRelease(blurredContext);
    free(blurredMemory);
    
    UIGraphicsPushContext(actionCircleContext);
    CGContextTranslateCTM(actionCircleContext, actionCircleContextSize.width / 2.0f, actionCircleContextSize.height / 2.0f);
    CGContextScaleCTM(actionCircleContext, 1.0f, -1.0f);
    CGContextTranslateCTM(actionCircleContext, -actionCircleContextSize.width / 2.0f, -actionCircleContextSize.height / 2.0f);
    
    CGContextSetInterpolationQuality(actionCircleContext, kCGInterpolationLow);
    CGContextSetBlendMode(actionCircleContext, kCGBlendModeCopy);
    
    [source drawInRect:CGRectMake((actionCircleContextSize.width - targetContextSize.width) / 2.0f, (actionCircleContextSize.height - targetContextSize.height) / 2.0f, targetContextSize.width, targetContextSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    brightenAndBlurImage(actionCircleMemory, actionCircleContextSize.width, actionCircleContextSize.height, (int)actionCircleBytesPerRow, scale < 2);
    
    CGContextBeginPath(actionCircleContext);
    CGContextAddRect(actionCircleContext, CGRectMake(0.0f, 0.0f, actionCircleContextSize.width, actionCircleContextSize.height));
    CGContextAddEllipseInRect(actionCircleContext, CGRectMake(0.0f, 0.0f, actionCircleContextSize.width, actionCircleContextSize.height));
    CGContextClosePath(actionCircleContext);
    
    CGContextSetFillColorWithColor(actionCircleContext, [UIColor clearColor].CGColor);
    CGContextEOFillPath(actionCircleContext);
    
    CGImageRef actionCircleBitmapImage = CGBitmapContextCreateImage(actionCircleContext);
    UIImage *actionCircleImage = [[UIImage alloc] initWithCGImage:actionCircleBitmapImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(actionCircleBitmapImage);
    
    CGContextRelease(actionCircleContext);
    free(actionCircleMemory);
    
    TGStaticBackdropAreaData *timestampBackdropArea = createTimestampBackdropArea(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, CGSizeMake(size.width, size.height));
    TGStaticBackdropAreaData *additionalDataBackdropArea = createAdditionalDataBackdropArea(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, CGSizeMake(size.width, size.height));
    
    if (attachmentBorder)
    {
        addAttachmentImageCorners(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, position, 1.0f);
    }
    else
    {
        TGAddImageCorners(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, cornerRadius, position);
    }
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    TGStaticBackdropImageData *backdropData = [[TGStaticBackdropImageData alloc] init];
    [backdropData setBackdropArea:[[TGStaticBackdropAreaData alloc] initWithBackground:actionCircleImage] forKey:TGStaticBackdropMessageActionCircle];
    
    [backdropData setBackdropArea:timestampBackdropArea forKey:TGStaticBackdropMessageTimestamp];
    [backdropData setBackdropArea:additionalDataBackdropArea forKey:TGStaticBackdropMessageAdditionalData];
    
    [image setStaticBackdropImageData:backdropData];
    
    return image;
}

UIImage *TGSecretBlurredAttachmentImage(UIImage *source, CGSize size, uint32_t *averageColor, bool attachmentBorder, int position)
{
    return TGSecretBlurredAttachmentWithCornerRadiusImage(source, size, averageColor, attachmentBorder, 13, position);
}

UIImage *TGSecretBlurredAttachmentWithCornerRadiusImage(UIImage *source, CGSize size, uint32_t *averageColor, bool attachmentBorder, CGFloat cornerRadius, int position)
{
    CGFloat scale = TGScreenScaling(); //TGIsRetina() ? 2.0f : 1.0f;
    
    CGSize fittedSize = fitSize(size, CGSizeMake(40, 40));
    
    CGFloat actionCircleDiameter = 50.0f;
    
    const struct { int width, height; } blurredContextSize = { (int)fittedSize.width, (int)fittedSize.height };
    const struct { int width, height; } targetContextSize = { (int)(size.width * scale), (int)(size.height * scale)};
    const struct { int width, height; } actionCircleContextSize = { (int)(actionCircleDiameter * scale), (int)(actionCircleDiameter * scale) };
    
    size_t blurredBytesPerRow = ((4 * (int)blurredContextSize.width) + 15) & (~15);
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    size_t actionCircleBytesPerRow = ((4 * (int)actionCircleContextSize.width) + 15) & (~15);
    
    void *blurredMemory = malloc((int)(blurredBytesPerRow * blurredContextSize.height));
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    void *actionCircleMemory = malloc(((int)(actionCircleBytesPerRow * actionCircleContextSize.height)));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef blurredContext = CGBitmapContextCreate(blurredMemory, (int)blurredContextSize.width, (int)blurredContextSize.height, 8, blurredBytesPerRow, colorSpace, bitmapInfo);
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    CGContextRef actionCircleContext = CGBitmapContextCreate(actionCircleMemory, (int)actionCircleContextSize.width, (int)actionCircleContextSize.height, 8, actionCircleBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(blurredContext);
    CGContextTranslateCTM(blurredContext, blurredContextSize.width / 2.0f, blurredContextSize.height / 2.0f);
    CGContextScaleCTM(blurredContext, 1.0f, -1.0f);
    CGContextTranslateCTM(blurredContext, -blurredContextSize.width / 2.0f, -blurredContextSize.height / 2.0f);
    CGContextSetInterpolationQuality(blurredContext, kCGInterpolationLow);
    [source drawInRect:CGRectMake(0, 0, blurredContextSize.width, blurredContextSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    fastBlurMore((int)blurredContextSize.width, (int)blurredContextSize.height, (int)blurredBytesPerRow, blurredMemory);
    fastBlurMore((int)blurredContextSize.width, (int)blurredContextSize.height, (int)blurredBytesPerRow, blurredMemory);
    fastBlurMore((int)blurredContextSize.width, (int)blurredContextSize.height, (int)blurredBytesPerRow, blurredMemory);
    
    int32_t divisor = 256;
    vImage_Buffer dstBuffer1;
    dstBuffer1.width = (int)blurredContextSize.width;
    dstBuffer1.height = (int)blurredContextSize.height;
    dstBuffer1.rowBytes = blurredBytesPerRow;
    dstBuffer1.data = blurredMemory;
    vImageMatrixMultiply_ARGB8888(&dstBuffer1, &dstBuffer1, secretMatrix(NULL), divisor, NULL, NULL, kvImageDoNotTile);
    
    if (averageColor != NULL)
    {
        *averageColor = TGImageAverageColor(blurredMemory, blurredContextSize.width, blurredContextSize.height, (int)blurredBytesPerRow);
    }
    
    vImage_Buffer srcBuffer;
    srcBuffer.width = blurredContextSize.width;
    srcBuffer.height = blurredContextSize.height;
    srcBuffer.rowBytes = blurredBytesPerRow;
    srcBuffer.data = blurredMemory;
    
    vImage_Buffer dstBuffer;
    dstBuffer.width = targetContextSize.width;
    dstBuffer.height = targetContextSize.height;
    dstBuffer.rowBytes = targetBytesPerRow;
    dstBuffer.data = targetMemory;
    
    vImageScale_ARGB8888(&srcBuffer, &dstBuffer, NULL, kvImageDoNotTile);
    
    CGContextRelease(blurredContext);
    free(blurredMemory);
    
    UIGraphicsPushContext(actionCircleContext);
    CGContextTranslateCTM(actionCircleContext, actionCircleContextSize.width / 2.0f, actionCircleContextSize.height / 2.0f);
    CGContextScaleCTM(actionCircleContext, 1.0f, -1.0f);
    CGContextTranslateCTM(actionCircleContext, -actionCircleContextSize.width / 2.0f, -actionCircleContextSize.height / 2.0f);
    
    CGContextSetInterpolationQuality(actionCircleContext, kCGInterpolationLow);
    CGContextSetBlendMode(actionCircleContext, kCGBlendModeCopy);
    
    [source drawInRect:CGRectMake((actionCircleContextSize.width - targetContextSize.width) / 2.0f, (actionCircleContextSize.height - targetContextSize.height) / 2.0f, targetContextSize.width, targetContextSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    brightenAndBlurImage(actionCircleMemory, actionCircleContextSize.width, actionCircleContextSize.height, (int)actionCircleBytesPerRow, scale < 2);
    
    CGContextBeginPath(actionCircleContext);
    CGContextAddRect(actionCircleContext, CGRectMake(0.0f, 0.0f, actionCircleContextSize.width, actionCircleContextSize.height));
    CGContextAddEllipseInRect(actionCircleContext, CGRectMake(0.0f, 0.0f, actionCircleContextSize.width, actionCircleContextSize.height));
    CGContextClosePath(actionCircleContext);
    
    CGContextSetFillColorWithColor(actionCircleContext, [UIColor clearColor].CGColor);
    CGContextEOFillPath(actionCircleContext);
    
    CGImageRef actionCircleBitmapImage = CGBitmapContextCreateImage(actionCircleContext);
    UIImage *actionCircleImage = [[UIImage alloc] initWithCGImage:actionCircleBitmapImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(actionCircleBitmapImage);
    
    CGContextRelease(actionCircleContext);
    free(actionCircleMemory);
    
    TGStaticBackdropAreaData *timestampBackdropArea = createTimestampBackdropArea(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, CGSizeMake(size.width, size.height));
    TGStaticBackdropAreaData *additionalDataBackdropArea = createAdditionalDataBackdropArea(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, CGSizeMake(size.width, size.height));
    
    if (attachmentBorder) {
        addAttachmentImageCorners(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, position, 1.0f);
    } else {
        TGAddImageCorners(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, cornerRadius, position);
    }
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    TGStaticBackdropImageData *backdropData = [[TGStaticBackdropImageData alloc] init];
    [backdropData setBackdropArea:[[TGStaticBackdropAreaData alloc] initWithBackground:actionCircleImage] forKey:TGStaticBackdropMessageActionCircle];
    
    [backdropData setBackdropArea:timestampBackdropArea forKey:TGStaticBackdropMessageTimestamp];
    [backdropData setBackdropArea:additionalDataBackdropArea forKey:TGStaticBackdropMessageAdditionalData];
    
    [image setStaticBackdropImageData:backdropData];
    
    return image;
}

UIImage *TGBlurredFileImage(UIImage *source, CGSize size, uint32_t *averageColor, int borderRadius)
{
    CGFloat scale = TGScreenScaling(); //TGIsRetina() ? 2.0f : 1.0f;
    
    CGSize fittedSize = fitSize(size, CGSizeMake(90, 90));
    
    CGFloat actionCircleDiameter = 50.0f;
    
    const struct { int width, height; } blurredContextSize = { (int)fittedSize.width, (int)fittedSize.height };
    const struct { int width, height; } targetContextSize = { (int)(size.width * scale), (int)(size.height * scale)};
    const struct { int width, height; } actionCircleContextSize = { (int)(actionCircleDiameter * scale), (int)(actionCircleDiameter * scale) };
    
    size_t blurredBytesPerRow = ((4 * (int)blurredContextSize.width) + 15) & (~15);
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    size_t actionCircleBytesPerRow = ((4 * (int)actionCircleContextSize.width) + 15) & (~15);
    
    void *blurredMemory = malloc((int)(blurredBytesPerRow * blurredContextSize.height));
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    void *actionCircleMemory = malloc(((int)(actionCircleBytesPerRow * actionCircleContextSize.height)));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef blurredContext = CGBitmapContextCreate(blurredMemory, (int)blurredContextSize.width, (int)blurredContextSize.height, 8, blurredBytesPerRow, colorSpace, bitmapInfo);
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    CGContextRef actionCircleContext = CGBitmapContextCreate(actionCircleMemory, (int)actionCircleContextSize.width, (int)actionCircleContextSize.height, 8, actionCircleBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(blurredContext);
    CGContextTranslateCTM(blurredContext, blurredContextSize.width / 2.0f, blurredContextSize.height / 2.0f);
    CGContextScaleCTM(blurredContext, 1.0f, -1.0f);
    CGContextTranslateCTM(blurredContext, -blurredContextSize.width / 2.0f, -blurredContextSize.height / 2.0f);
    CGContextSetInterpolationQuality(blurredContext, kCGInterpolationLow);
    [source drawInRect:CGRectMake(0, 0, blurredContextSize.width, blurredContextSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    fastBlur((int)blurredContextSize.width, (int)blurredContextSize.height, (int)blurredBytesPerRow, blurredMemory);
    
    if (averageColor != NULL)
    {
        *averageColor = TGImageAverageColor(blurredMemory, blurredContextSize.width, blurredContextSize.height, (int)blurredBytesPerRow);
    }
    
    vImage_Buffer srcBuffer;
    srcBuffer.width = blurredContextSize.width;
    srcBuffer.height = blurredContextSize.height;
    srcBuffer.rowBytes = blurredBytesPerRow;
    srcBuffer.data = blurredMemory;
    
    vImage_Buffer dstBuffer;
    dstBuffer.width = targetContextSize.width;
    dstBuffer.height = targetContextSize.height;
    dstBuffer.rowBytes = targetBytesPerRow;
    dstBuffer.data = targetMemory;
    
    vImageScale_ARGB8888(&srcBuffer, &dstBuffer, NULL, kvImageDoNotTile);
    
    CGContextRelease(blurredContext);
    free(blurredMemory);
    
    UIGraphicsPushContext(actionCircleContext);
    CGContextTranslateCTM(actionCircleContext, actionCircleContextSize.width / 2.0f, actionCircleContextSize.height / 2.0f);
    CGContextScaleCTM(actionCircleContext, 1.0f, -1.0f);
    CGContextTranslateCTM(actionCircleContext, -actionCircleContextSize.width / 2.0f, -actionCircleContextSize.height / 2.0f);
    
    CGContextSetInterpolationQuality(actionCircleContext, kCGInterpolationLow);
    CGContextSetBlendMode(actionCircleContext, kCGBlendModeCopy);
    
    [source drawInRect:CGRectMake((actionCircleContextSize.width - targetContextSize.width) / 2.0f, (actionCircleContextSize.height - targetContextSize.height) / 2.0f, targetContextSize.width, targetContextSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    brightenAndBlurImage(actionCircleMemory, actionCircleContextSize.width, actionCircleContextSize.height, (int)actionCircleBytesPerRow, scale < 2);
    
    CGContextBeginPath(actionCircleContext);
    CGContextAddRect(actionCircleContext, CGRectMake(0.0f, 0.0f, actionCircleContextSize.width, actionCircleContextSize.height));
    CGContextAddEllipseInRect(actionCircleContext, CGRectMake(0.0f, 0.0f, actionCircleContextSize.width, actionCircleContextSize.height));
    CGContextClosePath(actionCircleContext);
    
    CGContextSetFillColorWithColor(actionCircleContext, [UIColor clearColor].CGColor);
    CGContextEOFillPath(actionCircleContext);
    
    CGImageRef actionCircleBitmapImage = CGBitmapContextCreateImage(actionCircleContext);
    UIImage *actionCircleImage = [[UIImage alloc] initWithCGImage:actionCircleBitmapImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(actionCircleBitmapImage);
    
    CGContextRelease(actionCircleContext);
    free(actionCircleMemory);
    
    TGStaticBackdropAreaData *timestampBackdropArea = createTimestampBackdropArea(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, CGSizeMake(size.width, size.height));
    TGStaticBackdropAreaData *additionalDataBackdropArea = createAdditionalDataBackdropArea(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, CGSizeMake(size.width, size.height));
    
    if (borderRadius != 0)
    {
        TGAddImageCorners(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, (int)(borderRadius), 0);
    }
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    TGStaticBackdropImageData *backdropData = [[TGStaticBackdropImageData alloc] init];
    [backdropData setBackdropArea:[[TGStaticBackdropAreaData alloc] initWithBackground:actionCircleImage] forKey:TGStaticBackdropMessageActionCircle];
    
    [backdropData setBackdropArea:timestampBackdropArea forKey:TGStaticBackdropMessageTimestamp];
    [backdropData setBackdropArea:additionalDataBackdropArea forKey:TGStaticBackdropMessageAdditionalData];
    
    [image setStaticBackdropImageData:backdropData];
    
    return image;
}

UIImage *TGBlurredAlphaImage(UIImage *source, CGSize size)
{
    CGFloat scale = TGIsRetina() ? 2.0f : 1.0f;
    
    CGSize fittedSize = fitSize(size, CGSizeMake(90, 90));
    
    const struct { int width, height; } blurredContextSize = { (int)fittedSize.width, (int)fittedSize.height };
    const struct { int width, height; } targetContextSize = { (int)(size.width * scale), (int)(size.height * scale)};
    
    size_t blurredBytesPerRow = ((4 * (int)blurredContextSize.width) + 15) & (~15);
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    
    void *blurredMemory = malloc((int)(blurredBytesPerRow * blurredContextSize.height));
    memset(blurredMemory, 0, blurredBytesPerRow * blurredContextSize.height);
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef blurredContext = CGBitmapContextCreate(blurredMemory, (int)blurredContextSize.width, (int)blurredContextSize.height, 8, blurredBytesPerRow, colorSpace, bitmapInfo);
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(blurredContext);
    CGContextTranslateCTM(blurredContext, blurredContextSize.width / 2.0f, blurredContextSize.height / 2.0f);
    CGContextScaleCTM(blurredContext, 1.0f, -1.0f);
    CGContextTranslateCTM(blurredContext, -blurredContextSize.width / 2.0f, -blurredContextSize.height / 2.0f);
    CGContextSetInterpolationQuality(blurredContext, kCGInterpolationLow);
    [source drawInRect:CGRectMake(6, 6, blurredContextSize.width - 12, blurredContextSize.height - 12) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    vImage_Buffer srcBuffer;
    srcBuffer.width = blurredContextSize.width;
    srcBuffer.height = blurredContextSize.height;
    srcBuffer.rowBytes = blurredBytesPerRow;
    srcBuffer.data = blurredMemory;
    
    {
        vImage_Buffer dstBuffer;
        dstBuffer.width = blurredContextSize.width;
        dstBuffer.height = blurredContextSize.height;
        dstBuffer.rowBytes = blurredBytesPerRow;
        dstBuffer.data = targetMemory;
        
        int boxSize = (int)(0.02f * 100);
        boxSize = boxSize - (boxSize % 2) + 1;
        
        vImageBoxConvolve_ARGB8888(&srcBuffer, &dstBuffer, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
        vImageBoxConvolve_ARGB8888(&dstBuffer, &srcBuffer, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
    }
    
    vImage_Buffer dstBuffer;
    dstBuffer.width = targetContextSize.width;
    dstBuffer.height = targetContextSize.height;
    dstBuffer.rowBytes = targetBytesPerRow;
    dstBuffer.data = targetMemory;
    
    vImageScale_ARGB8888(&srcBuffer, &dstBuffer, NULL, kvImageDoNotTile);
    
    CGContextRelease(blurredContext);
    free(blurredMemory);
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    [image setExtendedEdgeInsets:UIEdgeInsetsMake(12.0f, 12.0f, 12.0f, 12.0f)];
    
    return image;
}

UIImage *TGBlurredRectangularImage(UIImage *source, bool more, CGSize size, CGSize renderSize, uint32_t *averageColor, void (^pixelProcessingBlock)(void *, int, int, int))
{
    CGSize fittedSize = fitSize(size, CGSizeMake(90, 90));
    if ((int)(fittedSize.width) % 2 != 0) {
        fittedSize.width += 1.0;
    }
    CGSize fittedRenderSize = CGSizeMake(fittedSize.width / size.width * renderSize.width, fittedSize.height / size.height * renderSize.height);
    
    const struct { int width, height; } blurredContextSize = { (int)fittedSize.width, (int)fittedSize.height };
    const struct { int width, height; } targetContextSize = { (int)(size.width), (int)(size.height)};
    
    size_t blurredBytesPerRow = ((4 * (int)blurredContextSize.width) + 15) & (~15);
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    
    void *blurredMemory = malloc((int)(blurredBytesPerRow * blurredContextSize.height));
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef blurredContext = CGBitmapContextCreate(blurredMemory, (int)blurredContextSize.width, (int)blurredContextSize.height, 8, blurredBytesPerRow, colorSpace, bitmapInfo);
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(blurredContext);
    CGContextTranslateCTM(blurredContext, blurredContextSize.width / 2.0f, blurredContextSize.height / 2.0f);
    CGContextScaleCTM(blurredContext, 1.0f, -1.0f);
    CGContextTranslateCTM(blurredContext, -blurredContextSize.width / 2.0f, -blurredContextSize.height / 2.0f);
    CGContextSetInterpolationQuality(blurredContext, kCGInterpolationLow);
    [source drawInRect:CGRectMake((blurredContextSize.width - fittedRenderSize.width) / 2.0f, (blurredContextSize.height - fittedRenderSize.height) / 2.0f, fittedRenderSize.width, fittedRenderSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    if (more) {
        fastBlurMore((int)blurredContextSize.width, (int)blurredContextSize.height, (int)blurredBytesPerRow, blurredMemory);
        fastBlurMore((int)blurredContextSize.width, (int)blurredContextSize.height, (int)blurredBytesPerRow, blurredMemory);
    } else {
        fastBlur((int)blurredContextSize.width, (int)blurredContextSize.height, (int)blurredBytesPerRow, blurredMemory);
    }
    
    if (averageColor != NULL)
    {
        *averageColor = TGImageAverageColor(blurredMemory, blurredContextSize.width, blurredContextSize.height, (int)blurredBytesPerRow);
    }
    
    vImage_Buffer srcBuffer;
    srcBuffer.width = blurredContextSize.width;
    srcBuffer.height = blurredContextSize.height;
    srcBuffer.rowBytes = blurredBytesPerRow;
    srcBuffer.data = blurredMemory;
    
    vImage_Buffer dstBuffer;
    dstBuffer.width = targetContextSize.width;
    dstBuffer.height = targetContextSize.height;
    dstBuffer.rowBytes = targetBytesPerRow;
    dstBuffer.data = targetMemory;
    
    vImageScale_ARGB8888(&srcBuffer, &dstBuffer, NULL, kvImageDoNotTile);
    
    CGContextRelease(blurredContext);
    free(blurredMemory);
    
    if (pixelProcessingBlock)
    {
        pixelProcessingBlock(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow);
    }
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    return image;
}

UIImage *TGLoadedAttachmentImage(UIImage *source, CGSize size, uint32_t *averageColor, bool attachmentBorder, int position)
{
    return TGLoadedAttachmentWithCornerRadiusImage(source, size, averageColor, attachmentBorder, attachmentBorder ? 14 : 15, 0, position);
}

UIImage *TGLoadedAttachmentWithCornerRadiusImage(UIImage *source, CGSize size, uint32_t *averageColor, bool attachmentBorder, int cornerRadius, int inset, int position)
{
    CGFloat scale = TGScreenScaling();
    if (cornerRadius < 0)
        cornerRadius = 0;
    
    CGFloat actionCircleDiameter = 50.0f;
    
    const struct { int width, height; } targetContextSize = { (int)(size.width * scale), (int)(size.height * scale) };
    const struct { int width, height; } actionCircleContextSize = { (int)(actionCircleDiameter * scale), (int)(actionCircleDiameter * scale) };
    
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    size_t actionCircleBytesPerRow = ((4 * (int)actionCircleContextSize.width) + 15) & (~15);
    
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    void *actionCircleMemory = malloc(((int)(actionCircleBytesPerRow * actionCircleContextSize.height)));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    CGContextRef actionCircleContext = CGBitmapContextCreate(actionCircleMemory, (int)actionCircleContextSize.width, (int)actionCircleContextSize.height, 8, actionCircleBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(actionCircleContext);
    CGContextTranslateCTM(actionCircleContext, actionCircleContextSize.width / 2.0f, actionCircleContextSize.height / 2.0f);
    CGContextScaleCTM(actionCircleContext, 1.0f, -1.0f);
    CGContextTranslateCTM(actionCircleContext, -actionCircleContextSize.width / 2.0f, -actionCircleContextSize.height / 2.0f);
    CGContextSetInterpolationQuality(actionCircleContext, kCGInterpolationLow);
    CGContextSetBlendMode(actionCircleContext, kCGBlendModeCopy);
    
    [source drawInRect:CGRectMake((actionCircleContextSize.width - targetContextSize.width) / 2.0f, (actionCircleContextSize.height - targetContextSize.height) / 2.0f, targetContextSize.width, targetContextSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    brightenAndBlurImage(actionCircleMemory, actionCircleContextSize.width, actionCircleContextSize.height, (int)actionCircleBytesPerRow, true);
    
    CGContextBeginPath(actionCircleContext);
    CGContextAddRect(actionCircleContext, CGRectMake(0.0f, 0.0f, actionCircleContextSize.width, actionCircleContextSize.height));
    CGContextAddEllipseInRect(actionCircleContext, CGRectMake(0.0f, 0.0f, actionCircleContextSize.width, actionCircleContextSize.height));
    CGContextClosePath(actionCircleContext);
    
    CGContextSetFillColorWithColor(actionCircleContext, [UIColor clearColor].CGColor);
    CGContextEOFillPath(actionCircleContext);
    
    UIGraphicsPopContext();
    
    CGImageRef actionCircleBitmapImage = CGBitmapContextCreateImage(actionCircleContext);
    UIImage *actionCircleImage = [[UIImage alloc] initWithCGImage:actionCircleBitmapImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(actionCircleBitmapImage);
    
    CGContextRelease(actionCircleContext);
    free(actionCircleMemory);
    
    UIGraphicsPushContext(targetContext);
    CGContextTranslateCTM(targetContext, targetContextSize.width / 2.0f, targetContextSize.height / 2.0f);
    CGContextScaleCTM(targetContext, 1.0f, -1.0f);
    CGContextTranslateCTM(targetContext, -targetContextSize.width / 2.0f, -targetContextSize.height / 2.0f);
    [source drawInRect:CGRectMake(-inset, -inset, targetContextSize.width + inset * 2, targetContextSize.height + inset * 2) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    if (averageColor != NULL)
    {
        *averageColor = TGImageAverageColor(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow);
    }
    
    TGStaticBackdropAreaData *timestampBackdropArea = createTimestampBackdropArea(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, CGSizeMake(size.width, size.height));
    TGStaticBackdropAreaData *additionalDataBackdropArea = createAdditionalDataBackdropArea(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, CGSizeMake(size.width, size.height));
    
    if (attachmentBorder)
    {
        addAttachmentImageCorners(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, position, 1.0f);
    }
    else
    {
        if (cornerRadius > 0) {
            TGAddImageCorners(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, cornerRadius, position);
        }
    }
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    TGStaticBackdropImageData *backdropData = [[TGStaticBackdropImageData alloc] init];
    [backdropData setBackdropArea:[[TGStaticBackdropAreaData alloc] initWithBackground:actionCircleImage] forKey:TGStaticBackdropMessageActionCircle];
    
    [backdropData setBackdropArea:timestampBackdropArea forKey:TGStaticBackdropMessageTimestamp];
    [backdropData setBackdropArea:additionalDataBackdropArea forKey:TGStaticBackdropMessageAdditionalData];
    
    [image setStaticBackdropImageData:backdropData];
    
    return image;
}

UIImage *TGAnimationFrameAttachmentImage(UIImage *source, CGSize size, CGSize renderSize)
{
    CGFloat scale = TGIsRetina() ? 2.0f : 1.0f;
    
    renderSize.width *= scale;
    renderSize.height *= scale;
    
    const struct { int width, height; } targetContextSize = { (int)(size.width * scale), (int)(size.height * scale) };
    
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(targetContext);
    CGContextTranslateCTM(targetContext, targetContextSize.width / 2.0f, targetContextSize.height / 2.0f);
    CGContextScaleCTM(targetContext, 1.0f, -1.0f);
    CGContextTranslateCTM(targetContext, -targetContextSize.width / 2.0f, -targetContextSize.height / 2.0f);
    
    CGContextSetFillColorWithColor(targetContext, [UIColor blackColor].CGColor);
    CGContextFillRect(targetContext, CGRectMake(0, 0, targetContextSize.width, targetContextSize.height));
    CGRect imageRect = CGRectMake((targetContextSize.width - renderSize.width) / 2.0f, (targetContextSize.height - renderSize.height) / 2.0f, renderSize.width, renderSize.height);
    [source drawInRect:imageRect blendMode:kCGBlendModeNormal alpha:1.0f];
    UIGraphicsPopContext();
    
    addAttachmentImageCorners(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, 0, 1.0f);
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    return image;
}

UIImage *TGLoadedFileImage(UIImage *source, CGSize size, uint32_t *averageColor, int borderRadius)
{
    CGFloat scale = TGScreenScaling(); //TGIsRetina() ? 2.0f : 1.0f;
    
    CGFloat actionCircleDiameter = 50.0f;
    
    const struct { int width, height; } targetContextSize = { (int)(size.width * scale), (int)(size.height * scale) };
    const struct { int width, height; } actionCircleContextSize = { (int)(actionCircleDiameter * scale), (int)(actionCircleDiameter * scale) };
    
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    size_t actionCircleBytesPerRow = ((4 * (int)actionCircleContextSize.width) + 15) & (~15);
    
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    memset(targetMemory, 0xff, targetBytesPerRow * targetContextSize.height);
    void *actionCircleMemory = malloc(((int)(actionCircleBytesPerRow * actionCircleContextSize.height)));
    memset(actionCircleMemory, 0xff, actionCircleBytesPerRow * actionCircleContextSize.height);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    CGContextRef actionCircleContext = CGBitmapContextCreate(actionCircleMemory, (int)actionCircleContextSize.width, (int)actionCircleContextSize.height, 8, actionCircleBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(actionCircleContext);
    CGContextTranslateCTM(actionCircleContext, actionCircleContextSize.width / 2.0f, actionCircleContextSize.height / 2.0f);
    CGContextScaleCTM(actionCircleContext, 1.0f, -1.0f);
    CGContextTranslateCTM(actionCircleContext, -actionCircleContextSize.width / 2.0f, -actionCircleContextSize.height / 2.0f);
    CGContextSetInterpolationQuality(actionCircleContext, kCGInterpolationLow);
    CGContextSetBlendMode(actionCircleContext, kCGBlendModeCopy);
    
    [source drawInRect:CGRectMake((actionCircleContextSize.width - targetContextSize.width) / 2.0f, (actionCircleContextSize.height - targetContextSize.height) / 2.0f, targetContextSize.width, targetContextSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    brightenAndBlurImage(actionCircleMemory, actionCircleContextSize.width, actionCircleContextSize.height, (int)actionCircleBytesPerRow, true);
    
    CGContextBeginPath(actionCircleContext);
    CGContextAddRect(actionCircleContext, CGRectMake(0.0f, 0.0f, actionCircleContextSize.width, actionCircleContextSize.height));
    CGContextAddEllipseInRect(actionCircleContext, CGRectMake(0.0f, 0.0f, actionCircleContextSize.width, actionCircleContextSize.height));
    CGContextClosePath(actionCircleContext);
    
    CGContextSetFillColorWithColor(actionCircleContext, [UIColor clearColor].CGColor);
    CGContextEOFillPath(actionCircleContext);
    
    UIGraphicsPopContext();
    
    CGImageRef actionCircleBitmapImage = CGBitmapContextCreateImage(actionCircleContext);
    UIImage *actionCircleImage = [[UIImage alloc] initWithCGImage:actionCircleBitmapImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(actionCircleBitmapImage);
    
    CGContextRelease(actionCircleContext);
    free(actionCircleMemory);
    
    UIGraphicsPushContext(targetContext);
    CGContextTranslateCTM(targetContext, targetContextSize.width / 2.0f, targetContextSize.height / 2.0f);
    CGContextScaleCTM(targetContext, 1.0f, -1.0f);
    CGContextTranslateCTM(targetContext, -targetContextSize.width / 2.0f, -targetContextSize.height / 2.0f);
    [source drawInRect:CGRectMake(0, 0, targetContextSize.width, targetContextSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    if (averageColor != NULL)
        *averageColor = TGImageAverageColor(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow);
    
    if (borderRadius != 0)
    {
        TGAddImageCorners(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, (int)(borderRadius), 0);
    }
    
    TGStaticBackdropAreaData *timestampBackdropArea = createTimestampBackdropArea(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, CGSizeMake(size.width, size.height));
    TGStaticBackdropAreaData *additionalDataBackdropArea = createAdditionalDataBackdropArea(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, CGSizeMake(size.width, size.height));
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    TGStaticBackdropImageData *backdropData = [[TGStaticBackdropImageData alloc] init];
    [backdropData setBackdropArea:[[TGStaticBackdropAreaData alloc] initWithBackground:actionCircleImage] forKey:TGStaticBackdropMessageActionCircle];
    
    [backdropData setBackdropArea:timestampBackdropArea forKey:TGStaticBackdropMessageTimestamp];
    [backdropData setBackdropArea:additionalDataBackdropArea forKey:TGStaticBackdropMessageAdditionalData];
    
    [image setStaticBackdropImageData:backdropData];
    
    return image;
}

UIImage *TGReducedAttachmentImage(UIImage *source, CGSize originalSize, bool attachmentBorder, int position)
{
    return TGReducedAttachmentWithCornerRadiusImage(source, originalSize, attachmentBorder, attachmentBorder ? 14 : 15, position);
}

UIImage *TGReducedAttachmentWithCornerRadiusImage(UIImage *source, CGSize originalSize, bool attachmentBorder, int cornerRadius, int position)
{
    CGFloat scale = TGScreenScaling(); //TGIsRetina() ? 2.0f : 1.0f;
    
    CGSize size = CGSizeMake(CGFloor(originalSize.width * 0.4f), CGFloor(originalSize.height * 0.4f));
    cornerRadius = CGFloor(cornerRadius * 0.4f);
    
    const struct { int width, height; } targetContextSize = { (int)(size.width * scale), (int)(size.height * scale) };
    const struct { int width, height; } targetContextOriginalSize = { (int)(originalSize.width * scale), (int)(originalSize.height * scale) };
    
    CGFloat padding = 32.0f;
    CGFloat scaledWidth = targetContextOriginalSize.width / ((targetContextOriginalSize.width - padding * 2.0f) / (targetContextSize.width - padding * 2.0f));
    CGFloat scaledHeight = targetContextOriginalSize.height / ((targetContextOriginalSize.height - padding * 2.0f) / (targetContextSize.height - padding * 2.0f));
    
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(targetContext);
    
    CGContextSetInterpolationQuality(targetContext, kCGInterpolationMedium);
    
    CGContextSetFillColorWithColor(targetContext, [UIColor grayColor].CGColor);
    CGContextFillRect(targetContext, CGRectMake(0.0f, 0.0, targetContextSize.width, targetContextSize.height));
    
    CGContextTranslateCTM(targetContext, targetContextSize.width / 2.0f, targetContextSize.height / 2.0f);
    CGContextScaleCTM(targetContext, 1.0f, -1.0f);
    CGContextTranslateCTM(targetContext, -targetContextSize.width / 2.0f, -targetContextSize.height / 2.0f);
    
    CGContextSaveGState(targetContext);
    CGContextClipToRect(targetContext, CGRectMake(0.0f, 0.0f, padding, padding));
    [source drawInRect:CGRectMake(0, 0, targetContextOriginalSize.width, targetContextOriginalSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    CGContextRestoreGState(targetContext);

    CGContextSaveGState(targetContext);
    CGContextClipToRect(targetContext, CGRectMake(targetContextSize.width - padding, 0.0f, padding, padding));
    [source drawInRect:CGRectMake(targetContextSize.width - targetContextOriginalSize.width, 0, targetContextOriginalSize.width, targetContextOriginalSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    CGContextRestoreGState(targetContext);
    
    CGContextSaveGState(targetContext);
    CGContextClipToRect(targetContext, CGRectMake(0.0f, targetContextSize.height - padding, padding, padding));
    [source drawInRect:CGRectMake(0, targetContextSize.height - targetContextOriginalSize.height, targetContextOriginalSize.width, targetContextOriginalSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    CGContextRestoreGState(targetContext);
    
    CGContextSaveGState(targetContext);
    CGContextClipToRect(targetContext, CGRectMake(targetContextSize.width - padding, targetContextSize.height - padding, padding, padding));
    [source drawInRect:CGRectMake(targetContextSize.width - targetContextOriginalSize.width, targetContextSize.height - targetContextOriginalSize.height, targetContextOriginalSize.width, targetContextOriginalSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    CGContextRestoreGState(targetContext);
    
    CGContextSaveGState(targetContext);
    CGContextClipToRect(targetContext, CGRectMake(padding, 0.0f, targetContextSize.width - padding * 2, padding));
    [source drawInRect:CGRectMake((targetContextSize.width - scaledWidth) / 2.0f, 0, scaledWidth, targetContextOriginalSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    CGContextRestoreGState(targetContext);
    
    CGContextSaveGState(targetContext);
    CGContextClipToRect(targetContext, CGRectMake(padding, targetContextSize.height - padding, targetContextSize.width - padding * 2, padding));
    [source drawInRect:CGRectMake((targetContextSize.width - scaledWidth) / 2.0f, targetContextSize.height - targetContextOriginalSize.height, scaledWidth, targetContextOriginalSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    CGContextRestoreGState(targetContext);
    
    CGContextSaveGState(targetContext);
    CGContextClipToRect(targetContext, CGRectMake(0.0f, padding, padding, targetContextSize.height - padding * 2));
    [source drawInRect:CGRectMake(0, (targetContextSize.height - scaledHeight) / 2.0f, targetContextOriginalSize.width, scaledHeight) blendMode:kCGBlendModeCopy alpha:1.0f];
    CGContextRestoreGState(targetContext);
    
    CGContextSaveGState(targetContext);
    CGContextClipToRect(targetContext, CGRectMake(targetContextSize.width - padding, padding, padding, targetContextSize.height - padding * 2));
    [source drawInRect:CGRectMake(targetContextSize.width - targetContextOriginalSize.width, (targetContextSize.height - scaledHeight) / 2.0f, targetContextOriginalSize.width, scaledHeight) blendMode:kCGBlendModeCopy alpha:1.0f];
    CGContextRestoreGState(targetContext);
    
    CGContextClipToRect(targetContext, CGRectMake(padding, padding, targetContextSize.width - padding * 2, targetContextSize.height - padding * 2));
    [source drawInRect:CGRectMake((targetContextSize.width - scaledWidth) / 2.0f, (targetContextSize.height - scaledHeight) / 2.0f, scaledWidth, scaledHeight) blendMode:kCGBlendModeCopy alpha:1.0f];
    
    UIGraphicsPopContext();
    
//    if (attachmentBorder)
//        addAttachmentImageCorners(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, position, 0.4f);
//    else
//    {
//        TGAddImageCorners(targetMemory, targetContextSize.width, targetContextSize.height, (int)(int)targetBytesPerRow, cornerRadius, position);
//    }
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    //return image;
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(padding / scale, padding / scale, padding / scale, padding / scale) resizingMode:UIImageResizingModeStretch];
}

UIImage *TGBlurredBackgroundImage(UIImage *source, CGSize size)
{
    CGFloat scale = source.scale;
    
    const struct { int width, height; } targetContextSize = { (int)(size.width * scale), (int)(size.height * scale) };
    
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(targetContext);
    CGContextTranslateCTM(targetContext, targetContextSize.width / 2.0f, targetContextSize.height / 2.0f);
    CGContextScaleCTM(targetContext, 1.0f, -1.0f);
    CGContextTranslateCTM(targetContext, -targetContextSize.width / 2.0f, -targetContextSize.height / 2.0f);
    [source drawInRect:CGRectMake(0, 0, targetContextSize.width, targetContextSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    brightenAndBlurImage(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, false);
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    return image;
}

UIImage *TGRoundImage(UIImage *source, CGSize size)
{
    CGFloat scale = TGIsRetina() ? 2.0f : 1.0f;
    
    const struct { int width, height; } targetContextSize = { (int)(size.width * scale), (int)(size.height * scale) };
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    memset(targetMemory, 0, (int)(targetBytesPerRow * targetContextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(targetContext);
    CGContextTranslateCTM(targetContext, targetContextSize.width / 2.0f, targetContextSize.height / 2.0f);
    CGContextScaleCTM(targetContext, 1.0f, -1.0f);
    CGContextTranslateCTM(targetContext, -targetContextSize.width / 2.0f, -targetContextSize.height / 2.0f);
    
    CGContextBeginPath(targetContext);
    CGContextAddEllipseInRect(targetContext, CGRectMake(0.0f, 0.0f, targetContextSize.width, targetContextSize.height));
    CGContextClip(targetContext);
    
    [source drawInRect:CGRectMake(0, 0, targetContextSize.width, targetContextSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    return image;
}

void TGPlainImageAverageColor(UIImage *source, uint32_t *averageColor)
{
    CGFloat scale = source.scale;
    CGSize size = source.size;
    
    const struct { int width, height; } targetContextSize = { (int)(size.width * scale), (int)(size.height * scale) };
    
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(targetContext);
    CGContextTranslateCTM(targetContext, targetContextSize.width / 2.0f, targetContextSize.height / 2.0f);
    CGContextScaleCTM(targetContext, 1.0f, -1.0f);
    CGContextTranslateCTM(targetContext, -targetContextSize.width / 2.0f, -targetContextSize.height / 2.0f);
    [source drawInRect:CGRectMake(0, 0, targetContextSize.width, targetContextSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    if (averageColor != NULL)
        *averageColor = TGImageAverageColor(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow);
    
    CGContextRelease(targetContext);
    free(targetMemory);
}

static void lightBlurImage(void *pixels, unsigned int width, unsigned int height, unsigned int stride)
{
    unsigned int tempWidth = width / 6;
    unsigned int tempHeight = height / 6;
    unsigned int tempStride = ((4 * tempWidth + 15) & (~15));
    void *tempPixels = malloc(tempStride * tempHeight);
    
    vImage_Buffer srcBuffer;
    srcBuffer.width = width;
    srcBuffer.height = height;
    srcBuffer.rowBytes = stride;
    srcBuffer.data = pixels;
    
    vImage_Buffer dstBuffer;
    dstBuffer.width = tempWidth;
    dstBuffer.height = tempHeight;
    dstBuffer.rowBytes = tempStride;
    dstBuffer.data = tempPixels;
    
    vImageScale_ARGB8888(&srcBuffer, &dstBuffer, NULL, kvImageDoNotTile);
    
    fastBlur(tempWidth, tempHeight, tempStride, tempPixels);
    
    vImageScale_ARGB8888(&dstBuffer, &srcBuffer, NULL, kvImageDoNotTile);
    
    free(tempPixels);
}

UIImage *TGCropBackdropImage(UIImage *source, CGSize size)
{
    CGFloat scale = source.scale;
    
    const struct { int width, height; } targetContextSize = { (int)(size.width * scale), (int)(size.height * scale) };
    
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(targetContext);
    CGContextTranslateCTM(targetContext, targetContextSize.width / 2.0f, targetContextSize.height / 2.0f);
    CGContextScaleCTM(targetContext, 1.0f, -1.0f);
    CGContextTranslateCTM(targetContext, -targetContextSize.width / 2.0f, -targetContextSize.height / 2.0f);
    CGContextSetFillColorWithColor(targetContext, [UIColor blackColor].CGColor);
    CGContextFillRect(targetContext, CGRectMake(0, 0, targetContextSize.width, targetContextSize.height));
    
    CGSize halfSize = CGSizeMake(CGFloor(size.width * scale / 2.0f), CGFloor(size.height * scale / 2.0f));
    [source drawInRect:CGRectMake((targetContextSize.width - halfSize.width) / 2, (targetContextSize.height - halfSize.height) / 2, halfSize.width, halfSize.height) blendMode:kCGBlendModeNormal alpha:0.6f];
    UIGraphicsPopContext();

    lightBlurImage(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow);
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    return image;
}

UIImage *TGCameraPositionSwitchImage(UIImage *source, CGSize size)
{
    return TGBlurredRectangularImage(source, true, size, size, NULL, nil);
}

UIImage *TGCameraModeSwitchImage(UIImage *source, CGSize size)
{
    return TGBlurredRectangularImage(source, true, size, size, NULL, nil);
}

UIImage *TGScaleAndCropImageToPixelSize(UIImage *source, CGSize size, CGSize renderSize, uint32_t *averageColor, void (^pixelProcessingBlock)(void *, int, int, int))
{
    const struct { int width, height; } targetContextSize = { (int)(size.width), (int)(size.height)};
    
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(targetContext);
    
    CGContextTranslateCTM(targetContext, targetContextSize.width / 2.0f, targetContextSize.height / 2.0f);
    CGContextScaleCTM(targetContext, 1.0f, -1.0f);
    CGContextTranslateCTM(targetContext, -targetContextSize.width / 2.0f, -targetContextSize.height / 2.0f);
    CGContextSetInterpolationQuality(targetContext, kCGInterpolationMedium);
    [source drawInRect:CGRectMake((size.width - renderSize.width) / 2.0f, (size.height - renderSize.height) / 2.0f, renderSize.width, renderSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIGraphicsPopContext();
    
    if (averageColor != NULL)
    {
        *averageColor = TGImageAverageColor(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow);
    }
    
    if (pixelProcessingBlock)
        pixelProcessingBlock(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow);
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    return image;
}

NSArray *TGBlurredBackgroundImages(UIImage *source, CGSize sourceSize)
{
    CGSize size = TGFitSize(sourceSize, CGSizeMake(220, 220));
    CGSize renderSize = size;
    
    const struct { int width, height; } targetContextSize = { (int)(size.width), (int)(size.height)};
    
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    UIGraphicsPushContext(targetContext);
    
    CGContextTranslateCTM(targetContext, targetContextSize.width / 2.0f, targetContextSize.height / 2.0f);
    CGContextScaleCTM(targetContext, 1.0f, -1.0f);
    CGContextTranslateCTM(targetContext, -targetContextSize.width / 2.0f, -targetContextSize.height / 2.0f);
    CGContextSetInterpolationQuality(targetContext, kCGInterpolationMedium);
    
    [source drawInRect:CGRectMake((size.width - renderSize.width) / 2.0f, (size.height - renderSize.height) / 2.0f, renderSize.width, renderSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    
    fastBlurMore(targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, targetMemory);
    fastBlurMore(targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, targetMemory);
    
    brightenImage(targetMemory, targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow);
    CGContextSetFillColorWithColor(targetContext, [UIColor colorWithWhite:1.0f alpha:0.15f].CGColor);
    CGContextFillRect(targetContext, CGRectMake(0.0f, 0.0f, targetContextSize.width, targetContextSize.height));
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *foregroundImage = [[UIImage alloc] initWithCGImage:bitmapImage];
    CGImageRelease(bitmapImage);
    
    [source drawInRect:CGRectMake((size.width - renderSize.width) / 2.0f, (size.height - renderSize.height) / 2.0f, renderSize.width, renderSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    
    fastBlurMore(targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, targetMemory);
    fastBlurMore(targetContextSize.width, targetContextSize.height, (int)targetBytesPerRow, targetMemory);
    
    CGContextSetFillColorWithColor(targetContext, [UIColor colorWithWhite:0.0f alpha:0.5f].CGColor);
    CGContextFillRect(targetContext, CGRectMake(0.0f, 0.0f, targetContextSize.width, targetContextSize.height));
    
    bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *backgroundImage = [[UIImage alloc] initWithCGImage:bitmapImage];
    CGImageRelease(bitmapImage);
    
    UIGraphicsPopContext();
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [array addObject:backgroundImage];
    [array addObject:foregroundImage];
    return array;
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
