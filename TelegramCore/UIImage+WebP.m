#import "UIImage+WebP.h"

#import "../third-party/libwebp/include/webp/decode.h"
#import "../third-party/libwebp/include/webp/encode.h"

@implementation UIImage (WebP)

+ (UIImage *)convertFromWebP:(NSData *)imgData {
    if (imgData == nil) {
        return nil;
    }
    
    // `WebPGetInfo` weill return image width and height
    int width = 0, height = 0;
    if(!WebPGetInfo([imgData bytes], [imgData length], &width, &height)) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Header formatting error." forKey:NSLocalizedDescriptionKey];
        return nil;
    }
    
    const struct { int width, height; } targetContextSize = { width, height};
    
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 15) & (~15);
    
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    UIGraphicsPushContext(targetContext);
    
    CGColorSpaceRelease(colorSpace);
    
    if (WebPDecodeBGRAInto(imgData.bytes, imgData.length, targetMemory, targetBytesPerRow * targetContextSize.height, (int)targetBytesPerRow) == NULL)
    {
        //[BridgingTrace objc_trace:@"WebP" what:@"error decoding webp"];
        return nil;
    }
    
    for (int y = 0; y < targetContextSize.height; y++)
    {
        for (int x = 0; x < targetContextSize.width; x++)
        {
            uint32_t *color = ((uint32_t *)&targetMemory[y * targetBytesPerRow + x * 4]);
            
            uint32_t a = (*color >> 24) & 0xff;
            uint32_t r = ((*color >> 16) & 0xff) * a;
            uint32_t g = ((*color >> 8) & 0xff) * a;
            uint32_t b = (*color & 0xff) * a;
            
            r = (r + 1 + (r >> 8)) >> 8;
            g = (g + 1 + (g >> 8)) >> 8;
            b = (b + 1 + (b >> 8)) >> 8;
            
            *color = (a << 24) | (r << 16) | (g << 8) | b;
        }
        
        for (size_t i = y * targetBytesPerRow + targetContextSize.width * 4; i < (targetBytesPerRow >> 2); i++)
        {
            *((uint32_t *)&targetMemory[i]) = 0;
        }
    }
    
    UIGraphicsPopContext();
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
    UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage scale:1.0f orientation:UIImageOrientationUp];
    CGImageRelease(bitmapImage);
    
    CGContextRelease(targetContext);
    free(targetMemory);
    
    return image;
}

@end
