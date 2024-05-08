#import <QOILoader/QOILoader.h>

#define QOI_IMPLEMENTATION
#import "qoi.h"

NSData * _Nullable encodeImageQOI(UIImage * _Nonnull image) {
    if (image == nil) {
        return nil;
    }
    CGImageRef cgImage = image.CGImage;
    if (cgImage == nil) {
        return nil;
    }
    CGDataProviderRef dataProvider = CGImageGetDataProvider(cgImage);
    if (dataProvider == nil) {
        return nil;
    }
    NSData *data = (__bridge_transfer NSData *)CGDataProviderCopyData(dataProvider);
    if (data == nil) {
        return nil;
    }
    if (CGImageGetBitsPerPixel(cgImage) / CGImageGetBitsPerComponent(cgImage) != 4) {
        return nil;
    }
    
    int outLength = 0;
    void *outBytes = qoi_encode(data.bytes, &(qoi_desc){
        .width = (unsigned int)CGImageGetWidth(cgImage),
        .height = (unsigned int)CGImageGetHeight(cgImage),
        .channels = 4,
        .colorspace = QOI_SRGB
    }, &outLength);
    if (outBytes == nil) {
        return nil;
    }
    return [[NSData alloc] initWithBytesNoCopy:outBytes length:outLength freeWhenDone:true];
}

static void releaseMallocedMemory(void *info, const void *data, size_t size) {
    free((void *)data);
}

UIImage * _Nullable decodeImageQOI(NSData * _Nonnull data) {
    qoi_desc desc;
    void *outPixels = qoi_decode(data.bytes, (int)data.length, &desc, 4);
    if (outPixels == nil) {
        return nil;
    }
    
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(nil, outPixels, desc.width * 4 * desc.height, releaseMallocedMemory);
    if (dataProvider == nil) {
        free(outPixels);
        return nil;
    }
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst;
    CGImageRef cgImage = CGImageCreate(desc.width, desc.height, 8, 8 * 4, desc.width * 4, CGColorSpaceCreateDeviceRGB(), bitmapInfo, dataProvider, nil, false, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
    
    UIImage *image = [[UIImage alloc] initWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    return image;
}
