#import <WebPBinding/UIImage+WebP.h>

#import "webp/encode.h"
#import "webp/decode.h"

@implementation WebP

+ (UIImage * _Nullable)convertFromWebP:(NSData * _Nonnull)imgData {
    if (imgData == nil) {
        return nil;
    }
    
    int width = 0, height = 0;
    if (!WebPGetInfo([imgData bytes], [imgData length], &width, &height)) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Header formatting error." forKey:NSLocalizedDescriptionKey];
        return nil;
    }
    
    const struct { int width, height; } targetContextSize = { width, height};
    
    size_t targetBytesPerRow = ((4 * (int)targetContextSize.width) + 31) & (~31);
    
    void *targetMemory = malloc((int)(targetBytesPerRow * targetContextSize.height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, (int)targetContextSize.width, (int)targetContextSize.height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    UIGraphicsPushContext(targetContext);
    
    CGColorSpaceRelease(colorSpace);
    
    if (WebPDecodeBGRAInto(imgData.bytes, imgData.length, targetMemory, targetBytesPerRow * targetContextSize.height, (int)targetBytesPerRow) == NULL) {
        //[BridgingTrace objc_trace:@"WebP" what:@"error decoding webp"];
        return nil;
    }
    
    for (int y = 0; y < targetContextSize.height; y++) {
        for (int x = 0; x < targetContextSize.width; x++) {
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
        
        for (size_t i = y * targetBytesPerRow + targetContextSize.width * 4; i < (targetBytesPerRow >> 2); i++) {
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
    
+ (NSData * _Nullable)convertToWebP:(UIImage * _Nonnull)image quality:(CGFloat)quality error:(NSError ** _Nullable)error {
    WebPPreset preset = WEBP_PRESET_DEFAULT;
    CGImageRef imageRef = [image CGImage];

    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    uint8_t *rawData = malloc(height * width * 4);

    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);

    WebPConfig config;
    if (!WebPConfigPreset(&config, preset, quality)) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Configuration preset failed to initialize." forKey:NSLocalizedDescriptionKey];
        if(error != NULL)
        *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@.errorDomain",  [[NSBundle mainBundle] bundleIdentifier]] code:-101 userInfo:errorDetail];
        
        free(rawData);
        return nil;
    }
    
    config.method = 6;
    
    if (!WebPValidateConfig(&config)) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"One or more configuration parameters are beyond their valid ranges." forKey:NSLocalizedDescriptionKey];
        if(error != NULL)
        *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@.errorDomain",  [[NSBundle mainBundle] bundleIdentifier]] code:-101 userInfo:errorDetail];
        
        free(rawData);
        return nil;
    }
    
    WebPPicture pic;
    if (!WebPPictureInit(&pic)) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Failed to initialize structure. Version mismatch." forKey:NSLocalizedDescriptionKey];
        if(error != NULL)
        *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@.errorDomain",  [[NSBundle mainBundle] bundleIdentifier]] code:-101 userInfo:errorDetail];
        
        free(rawData);
        return nil;
    }
    pic.width = (int)width;
    pic.height = (int)height;
    pic.colorspace = WEBP_YUV420;
    
    
//    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){12, 0, 0}]) {
        WebPPictureImportRGBA(&pic, rawData, (int)bytesPerRow);
//    } else {
//        WebPPictureImportBGRA(&pic, webPImageData, (int)webPBytesPerRow);
//    }
    
    WebPPictureARGBToYUVA(&pic, WEBP_YUV420);
    WebPCleanupTransparentArea(&pic);
    
    WebPMemoryWriter writer;
    WebPMemoryWriterInit(&writer);
    pic.writer = WebPMemoryWrite;
    pic.custom_ptr = &writer;
    WebPEncode(&config, &pic);
    
    NSData *webPFinalData = [NSData dataWithBytes:writer.mem length:writer.size];
    
    free(writer.mem);
    WebPPictureFree(&pic);
    free(rawData);
    
    return webPFinalData;
}


@end
