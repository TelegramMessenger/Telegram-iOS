#import <MozjpegBinding/MozjpegBinding.h>

#define USE_JPEGLI false

#import <mozjpeg/turbojpeg.h>
#import <mozjpeg/jpeglib.h>

#import <Accelerate/Accelerate.h>

#ifdef USE_JPEGXL
#include <jxl/encode.h>
#include <jxl/encode_cxx.h>
#include <jxl/decode.h>
#include <jxl/decode_cxx.h>
//#include <jxl/thread_parallel_runner.h>
//#include <jxl/thread_parallel_runner_cxx.h>
#endif

#include <limits.h>
#include <string.h>
#include <sstream>
#include <string>
#include <vector>

static inline float JXLGetDistance(int32_t quality) {
    if (quality == 0) {
        return 1.0f;
    } else if (quality >= 30) {
        return 0.1f + (float)(100 - MIN(100, quality)) * 0.09f;
    } else {
        return 6.24f + (float)pow(2.5f, (30.0 - quality) / 5.0) / 6.25f;
    }
}

NSData * _Nullable compressJPEGXLData(UIImage * _Nonnull sourceImage, int quality) {
    #ifdef USE_JPEGXL
    int width = (int)(sourceImage.size.width * sourceImage.scale);
    int height = (int)(sourceImage.size.height * sourceImage.scale);
    
    int targetBytesPerRow = ((4 * (int)width) + 31) & (~31);
    uint8_t *targetMemory = (uint8_t *)malloc((int)(targetBytesPerRow * height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, width, height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    UIGraphicsPushContext(targetContext);
    
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(targetContext, CGRectMake(0, 0, width, height), sourceImage.CGImage);
    
    UIGraphicsPopContext();
    
    int bufferBytesPerRow = ((3 * (int)width) + 31) & (~31);
    int bufferSize = bufferBytesPerRow * height;
    uint8_t *buffer = (uint8_t *)malloc(bufferBytesPerRow * height);
    
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            uint32_t *color = ((uint32_t *)&targetMemory[y * targetBytesPerRow + x * 4]);
            
            uint32_t r = ((*color >> 16) & 0xff);
            uint32_t g = ((*color >> 8) & 0xff);
            uint32_t b = (*color & 0xff);
            
            buffer[y * bufferBytesPerRow + x * 3 + 0] = r;
            buffer[y * bufferBytesPerRow + x * 3 + 1] = g;
            buffer[y * bufferBytesPerRow + x * 3 + 2] = b;
        }
    }
    
    CGContextRelease(targetContext);
    
    free(targetMemory);
    
    auto enc = JxlEncoderMake(nullptr);
    
    JxlPixelFormat pixel_format = {3, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 16};

    JxlBasicInfo basic_info;
    JxlEncoderInitBasicInfo(&basic_info);
    basic_info.xsize = width;
    basic_info.ysize = height;
    basic_info.bits_per_sample = 32;
    basic_info.exponent_bits_per_sample = 8;
    basic_info.uses_original_profile = JXL_FALSE;
    if (JXL_ENC_SUCCESS != JxlEncoderSetBasicInfo(enc.get(), &basic_info)) {
        free(buffer);
        return nil;
    }

    JxlColorEncoding color_encoding = {};
    JxlColorEncodingSetToSRGB(&color_encoding,
                              /*is_gray=*/pixel_format.num_channels < 3);
    if (JXL_ENC_SUCCESS != JxlEncoderSetColorEncoding(enc.get(), &color_encoding)) {
        free(buffer);
        return nil;
    }

    JxlEncoderFrameSettings* frame_settings =
        JxlEncoderFrameSettingsCreate(enc.get(), nullptr);

    JxlEncoderSetFrameDistance(frame_settings, JXLGetDistance(quality));
    JxlEncoderFrameSettingsSetOption(frame_settings, JXL_ENC_FRAME_SETTING_EFFORT, 8);
    
    if (JXL_ENC_SUCCESS != JxlEncoderAddImageFrame(frame_settings, &pixel_format, buffer, bufferSize)) {
        free(buffer);
        return nil;
    }
    JxlEncoderCloseInput(enc.get());

    NSMutableData *result = [[NSMutableData alloc] initWithLength:64];
    uint8_t *next_out = (uint8_t *)result.mutableBytes;
    size_t avail_out = result.length - (next_out - ((uint8_t *)result.mutableBytes));
    
    JxlEncoderStatus process_result = JXL_ENC_NEED_MORE_OUTPUT;
    while (process_result == JXL_ENC_NEED_MORE_OUTPUT) {
        process_result = JxlEncoderProcessOutput(enc.get(), &next_out, &avail_out);
        if (process_result == JXL_ENC_NEED_MORE_OUTPUT) {
            size_t offset = next_out - ((uint8_t *)result.mutableBytes);
            [result setLength:result.length * 2];
            next_out = ((uint8_t *)result.mutableBytes) + offset;
            avail_out = result.length - offset;
        }
    }
    [result setLength:next_out - ((uint8_t *)result.mutableBytes)];
    if (JXL_ENC_SUCCESS != process_result) {
        free(buffer);
        return nil;
    }
    
    free(buffer);
    return result;
    
  /*auto runner = JxlThreadParallelRunnerMake(
      nullptr,
      8);
  if (JXL_ENC_SUCCESS != JxlEncoderSetParallelRunner(enc.get(),
                                                     JxlThreadParallelRunner,
                                                     runner.get())) {
    fprintf(stderr, "JxlEncoderSetParallelRunner failed\n");
    return false;
  }*/
    #else
    return nil;
    #endif
}

UIImage * _Nullable decompressJPEGXLData(NSData * _Nonnull data) {
    #ifdef USE_JPEGXL
    //const uint8_t* jxl, size_t size, std::vector<float>* pixels, size_t* xsize, size_t* ysize, std::vector<uint8_t>* icc_profile
    
    auto dec = JxlDecoderMake(nullptr);
    if (JXL_DEC_SUCCESS != JxlDecoderSubscribeEvents(dec.get(), JXL_DEC_BASIC_INFO | JXL_DEC_COLOR_ENCODING | JXL_DEC_FULL_IMAGE)) {
        return nil;
    }
    
    /*if (JXL_DEC_SUCCESS != JxlDecoderSetParallelRunner(dec.get(), JxlResizableParallelRunner, runner.get())) {
        fprintf(stderr, "JxlDecoderSetParallelRunner failed\n");
        return false;
    }*/
    
    JxlBasicInfo info;
    JxlPixelFormat format = {4, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 0};
    
    JxlDecoderSetInput(dec.get(), (uint8_t const *)data.bytes, data.length);
    JxlDecoderCloseInput(dec.get());
    
    int xsize = 0;
    int ysize = 0;
    std::vector<uint8_t> icc_profile;
    
    std::vector<uint8_t> pixels;
    
    while (true) {
        JxlDecoderStatus status = JxlDecoderProcessInput(dec.get());
        
        if (status == JXL_DEC_ERROR) {
            return nil;
        } else if (status == JXL_DEC_NEED_MORE_INPUT) {
            return nil;
        } else if (status == JXL_DEC_BASIC_INFO) {
            if (JXL_DEC_SUCCESS != JxlDecoderGetBasicInfo(dec.get(), &info)) {
                return nil;
            }
            xsize = info.xsize;
            ysize = info.ysize;
            //JxlResizableParallelRunnerSetThreads(runner.get(), JxlResizableParallelRunnerSuggestThreads(info.xsize, info.ysize));
        } else if (status == JXL_DEC_COLOR_ENCODING) {
            // Get the ICC color profile of the pixel data
            size_t icc_size;
            if (JXL_DEC_SUCCESS != JxlDecoderGetICCProfileSize(dec.get(), JXL_COLOR_PROFILE_TARGET_DATA, &icc_size)) {
                fprintf(stderr, "JxlDecoderGetICCProfileSize failed\n");
                return nil;
            }
            icc_profile.resize(icc_size);
            if (JXL_DEC_SUCCESS != JxlDecoderGetColorAsICCProfile(dec.get(), JXL_COLOR_PROFILE_TARGET_DATA, icc_profile.data(), icc_profile.size())) {
                return nil;
            }
        } else if (status == JXL_DEC_NEED_IMAGE_OUT_BUFFER) {
            size_t buffer_size;
            if (JXL_DEC_SUCCESS != JxlDecoderImageOutBufferSize(dec.get(), &format, &buffer_size)) {
                return nil;
            }
            if (buffer_size != xsize * ysize * 4) {
                //return nil;
            }
            pixels.resize(buffer_size);
            void* pixels_buffer = (void*)pixels.data();
            size_t pixels_buffer_size = pixels.size() * sizeof(float);
            if (JXL_DEC_SUCCESS != JxlDecoderSetImageOutBuffer(dec.get(), &format, pixels_buffer, pixels_buffer_size)) {
                return nil;
            }
        } else if (status == JXL_DEC_FULL_IMAGE) {
            // Nothing to do. Do not yet return. If the image is an animation, more
            // full frames may be decoded. This example only keeps the last one.
        } else if (status == JXL_DEC_SUCCESS) {
            // All decoding successfully finished.
            // It's not required to call JxlDecoderReleaseInput(dec.get()) here since
            // the decoder will be destroyed.
            
            int width = xsize;
            int height = ysize;
            int sourceBytesPerRow = width * 4;
            int targetBytesPerRow = width * 4;
            vImage_Buffer source;
            source.width = width;
            source.height = height;
            source.rowBytes = sourceBytesPerRow;
            source.data = pixels.data();

            vImage_Buffer permuteTarget;
            permuteTarget.width = width;
            permuteTarget.height = height;
            permuteTarget.rowBytes = targetBytesPerRow;

            unsigned char *permuteTargetBuffer = (uint8_t *)malloc(targetBytesPerRow * height);
            permuteTarget.data = permuteTargetBuffer;

            const uint8_t permuteMap[4] = {2,1,0,3};
            vImagePermuteChannels_ARGB8888(&source, &permuteTarget, permuteMap, kvImageDoNotTile);

            NSData *resultData = [[NSData alloc] initWithBytesNoCopy:permuteTargetBuffer length:targetBytesPerRow * height deallocator:^(void * _Nonnull bytes, __unused NSUInteger length) {
                free(bytes);
            }];

            CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)resultData);

            static CGColorSpaceRef imageColorSpace;
            static CGBitmapInfo bitmapInfo;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), YES, 0);
                UIImage *refImage = UIGraphicsGetImageFromCurrentImageContext();
                imageColorSpace = CGColorSpaceRetain(CGImageGetColorSpace(refImage.CGImage));
                bitmapInfo = CGImageGetBitmapInfo(refImage.CGImage);
                UIGraphicsEndImageContext();
            });

            CGImageRef cgImg = CGImageCreate(width, height, 8, 32, targetBytesPerRow, imageColorSpace, bitmapInfo, dataProvider, NULL, true, kCGRenderingIntentDefault);

            CGDataProviderRelease(dataProvider);

            UIImage *resultImage = [[UIImage alloc] initWithCGImage:cgImg];
            CGImageRelease(cgImg);

            return resultImage;
        } else {
            return nil;
        }
    }
    
    return nil;
    #else
    return nil;
    #endif
}

static NSData *getHeaderPattern() {
    static NSData *value = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        value = [[NSData alloc] initWithBase64EncodedString:@"/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDACgcHiMeGSgjISMtKygwPGRBPDc3PHtYXUlkkYCZlo+AjIqgtObDoKrarYqMyP/L2u71////m8H////6/+b9//j/2wBDASstLTw1PHZBQXb4pYyl+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj/wAARCAAAAAADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwA=" options:0];
    });
    return value;
}

static NSData *getFooterPattern() {
    static NSData *value = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        value = [[NSData alloc] initWithBase64EncodedString:@"/9k=" options:0];
    });
    return value;
}

NSArray<NSNumber *> * _Nonnull extractJPEGDataScans(NSData * _Nonnull data) {
    NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] init];
    
    const uint8_t *dataBytes = (const uint8_t *)data.bytes;
    int offset = 0;
    while (offset < data.length) {
        bool found = false;
        for (int i = offset + 2; i < data.length - 1; i++) {
            if (dataBytes[i] == 0xffU && dataBytes[i + 1] == 0xdaU) {
                if (offset != 0) {
                    [result addObject:@(i)];
                }
                offset = i;
                found = true;
            }
        }
        if (!found) {
            break;
        }
    }
    
#if DEBUG
    static NSString *sessionPrefix = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sessionPrefix = [NSString stringWithFormat:@"%u", arc4random()];
    });
    
    NSString *randomId = [NSString stringWithFormat:@"%u", arc4random()];
    NSString *dirPath = [[NSTemporaryDirectory() stringByAppendingPathComponent:sessionPrefix] stringByAppendingPathComponent:randomId];
    [[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:true attributes:nil error:nil];
    for (int i = 0; i < result.count + 1; i++) {
        NSString *filePath = [dirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.jpg", i]];
        if (i == result.count) {
            [data writeToFile:filePath atomically:true];
        } else {
            [[data subdataWithRange:NSMakeRange(0, [result[i] intValue])] writeToFile:filePath atomically:true];
        }
    }
    NSLog(@"Path: %@", dirPath);
#endif
    
    return result;
}

#if USE_JPEGLI
NSData * _Nullable compressJPEGData(UIImage * _Nonnull sourceImage) {
    int width = (int)(sourceImage.size.width * sourceImage.scale);
    int height = (int)(sourceImage.size.height * sourceImage.scale);
    
    int targetBytesPerRow = ((4 * (int)width) + 31) & (~31);
    uint8_t *targetMemory = malloc((int)(targetBytesPerRow * height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, width, height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    UIGraphicsPushContext(targetContext);
    
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(targetContext, CGRectMake(0, 0, width, height), sourceImage.CGImage);
    
    UIGraphicsPopContext();
    
    int bufferBytesPerRow = ((3 * (int)width) + 31) & (~31);
    uint8_t *buffer = malloc(bufferBytesPerRow * height);
    
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            uint32_t *color = ((uint32_t *)&targetMemory[y * targetBytesPerRow + x * 4]);
            
            uint32_t r = ((*color >> 16) & 0xff);
            uint32_t g = ((*color >> 8) & 0xff);
            uint32_t b = (*color & 0xff);
            
            buffer[y * bufferBytesPerRow + x * 3 + 0] = r;
            buffer[y * bufferBytesPerRow + x * 3 + 1] = g;
            buffer[y * bufferBytesPerRow + x * 3 + 2] = b;
        }
    }
    
    CGContextRelease(targetContext);
    
    free(targetMemory);
    
    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;
    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);
    
    uint8_t *outBuffer = NULL;
    unsigned long outSize = 0;
    jpeg_mem_dest(&cinfo, &outBuffer, &outSize);
    
    cinfo.image_width = (uint32_t)width;
    cinfo.image_height = (uint32_t)height;
    cinfo.input_components = 3;
    cinfo.in_color_space = JCS_RGB;
    //jpeg_c_set_int_param(&cinfo, JINT_COMPRESS_PROFILE, JCP_FASTEST);
    jpeg_set_defaults(&cinfo);
    cinfo.arith_code = FALSE;
    cinfo.dct_method = JDCT_ISLOW;
    cinfo.optimize_coding = TRUE;
    jpeg_set_quality(&cinfo, 72, 1);
    jpeg_simple_progression(&cinfo);
    jpeg_start_compress(&cinfo, 1);
    
    JSAMPROW rowPointer[1];
    while (cinfo.next_scanline < cinfo.image_height) {
        rowPointer[0] = (JSAMPROW)(buffer + cinfo.next_scanline * bufferBytesPerRow);
        jpeg_write_scanlines(&cinfo, rowPointer, 1);
    }
    
    jpeg_finish_compress(&cinfo);
    
    NSData *result = [[NSData alloc] initWithBytes:outBuffer length:outSize];
    
    jpeg_destroy_compress(&cinfo);
    
    free(buffer);
    
    return result;
}
#else
NSData * _Nullable compressJPEGData(UIImage * _Nonnull sourceImage, NSString * _Nonnull tempFilePath) {
    FILE *outfile = fopen([tempFilePath UTF8String], "w");
    if (!outfile) {
        return nil;
    }
    
    int width = (int)(sourceImage.size.width * sourceImage.scale);
    int height = (int)(sourceImage.size.height * sourceImage.scale);
    
    int targetBytesPerRow = ((4 * (int)width) + 31) & (~31);
    uint8_t *targetMemory = (uint8_t *)malloc((int)(targetBytesPerRow * height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, width, height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    UIGraphicsPushContext(targetContext);
    
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(targetContext, CGRectMake(0, 0, width, height), sourceImage.CGImage);
    
    UIGraphicsPopContext();
    
    int bufferBytesPerRow = ((3 * (int)width) + 31) & (~31);
    uint8_t *buffer = (uint8_t *)malloc(bufferBytesPerRow * height);
    
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            uint32_t *color = ((uint32_t *)&targetMemory[y * targetBytesPerRow + x * 4]);
            
            uint32_t r = ((*color >> 16) & 0xff);
            uint32_t g = ((*color >> 8) & 0xff);
            uint32_t b = (*color & 0xff);
            
            buffer[y * bufferBytesPerRow + x * 3 + 0] = r;
            buffer[y * bufferBytesPerRow + x * 3 + 1] = g;
            buffer[y * bufferBytesPerRow + x * 3 + 2] = b;
        }
    }
    
    CGContextRelease(targetContext);
    
    free(targetMemory);
    
    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;
    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);
    
    jpeg_stdio_dest(&cinfo, outfile);
    
    cinfo.image_width = (uint32_t)width;
    cinfo.image_height = (uint32_t)height;
    cinfo.input_components = 3;
    cinfo.in_color_space = JCS_RGB;
    jpeg_c_set_int_param(&cinfo, JINT_COMPRESS_PROFILE, JCP_FASTEST);
    jpeg_set_defaults(&cinfo);
    cinfo.arith_code = FALSE;
    cinfo.dct_method = JDCT_ISLOW;
    cinfo.optimize_coding = TRUE;
    jpeg_set_quality(&cinfo, 72, 1);
    jpeg_simple_progression(&cinfo);
    jpeg_start_compress(&cinfo, 1);
    
    JSAMPROW rowPointer[1];
    while (cinfo.next_scanline < cinfo.image_height) {
        rowPointer[0] = (JSAMPROW)(buffer + cinfo.next_scanline * bufferBytesPerRow);
        jpeg_write_scanlines(&cinfo, rowPointer, 1);
    }
    
    jpeg_finish_compress(&cinfo);
    jpeg_destroy_compress(&cinfo);
    
    fclose(outfile);
    
    NSData *result = [[NSData alloc] initWithContentsOfFile:tempFilePath];
    
    free(buffer);
    
    [[NSFileManager defaultManager] removeItemAtPath:tempFilePath error:nil];
    
    return result;
}
#endif

#if USE_JPEGLI
NSData * _Nullable compressMiniThumbnail(UIImage * _Nonnull image, CGSize size) {
    CGSize fittedSize = image.size;
    if (fittedSize.width > size.width) {
        fittedSize = CGSizeMake(size.width, (int)((fittedSize.height * size.width / MAX(fittedSize.width, 1.0f))));
    }
    if (fittedSize.height > size.height) {
        fittedSize = CGSizeMake((int)((fittedSize.width * size.height / MAX(fittedSize.height, 1.0f))), size.height);
    }
    
    int width = (int)fittedSize.width;
    int height = (int)fittedSize.height;
    
    int targetBytesPerRow = ((4 * (int)width) + 31) & (~31);
    uint8_t *targetMemory = malloc((int)(targetBytesPerRow * height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, width, height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    UIGraphicsPushContext(targetContext);
    
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(targetContext, CGRectMake(0, 0, width, height), image.CGImage);
    
    UIGraphicsPopContext();
    
    int bufferBytesPerRow = ((3 * (int)width) + 31) & (~31);
    uint8_t *buffer = malloc(bufferBytesPerRow * height);
    
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            uint32_t *color = ((uint32_t *)&targetMemory[y * targetBytesPerRow + x * 4]);
            
            uint32_t r = ((*color >> 16) & 0xff);
            uint32_t g = ((*color >> 8) & 0xff);
            uint32_t b = (*color & 0xff);
            
            buffer[y * bufferBytesPerRow + x * 3 + 0] = r;
            buffer[y * bufferBytesPerRow + x * 3 + 1] = g;
            buffer[y * bufferBytesPerRow + x * 3 + 2] = b;
        }
    }
    
    CGContextRelease(targetContext);
    
    free(targetMemory);
    
    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;
    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);
    
    uint8_t *outBuffer = NULL;
    unsigned long outSize = 0;
    jpeg_mem_dest(&cinfo, &outBuffer, &outSize);
    
    cinfo.image_width = (uint32_t)width;
    cinfo.image_height = (uint32_t)height;
    cinfo.input_components = 3;
    cinfo.in_color_space = JCS_RGB;
    //jpeg_c_set_int_param(&cinfo, JINT_COMPRESS_PROFILE, JCP_FASTEST);
    jpeg_set_defaults(&cinfo);
    cinfo.arith_code = FALSE;
    cinfo.dct_method = JDCT_ISLOW;
    cinfo.optimize_coding = FALSE;
    jpeg_set_quality(&cinfo, 20, 1);
    jpeg_start_compress(&cinfo, 1);
    
    JSAMPROW rowPointer[1];
    while (cinfo.next_scanline < cinfo.image_height) {
        rowPointer[0] = (JSAMPROW)(buffer + cinfo.next_scanline * bufferBytesPerRow);
        jpeg_write_scanlines(&cinfo, rowPointer, 1);
    }
    
    jpeg_finish_compress(&cinfo);
    
    NSMutableData *serializedData = nil;
    
    NSData *headerPattern = getHeaderPattern();
    NSData *footerPattern = getFooterPattern();
    if (outBuffer[164] == height && outBuffer[166] == width && headerPattern != nil && footerPattern != nil) {
        outBuffer[164] = 0;
        outBuffer[166] = 0;
        
        if (memcmp(headerPattern.bytes, outBuffer, headerPattern.length) == 0) {
            if (memcmp(footerPattern.bytes, outBuffer + outSize - footerPattern.length, footerPattern.length) == 0) {
                serializedData = [[NSMutableData alloc] init];
                uint8_t version = 1;
                [serializedData appendBytes:&version length:1];
                uint8_t outWidth = (uint8_t)width;
                uint8_t outHeight = (uint8_t)height;
                [serializedData appendBytes:&outHeight length:1];
                [serializedData appendBytes:&outWidth length:1];
                unsigned long contentSize = outSize - headerPattern.length - footerPattern.length;
                [serializedData appendBytes:outBuffer + headerPattern.length length:contentSize];
            }
        }
    }
    
    jpeg_destroy_compress(&cinfo);
    
    free(buffer);
    
    return serializedData;
}
#else
NSData * _Nullable compressMiniThumbnail(UIImage * _Nonnull image, CGSize size) {
    CGSize fittedSize = image.size;
    if (fittedSize.width > size.width) {
        fittedSize = CGSizeMake(size.width, (int)((fittedSize.height * size.width / MAX(fittedSize.width, 1.0f))));
    }
    if (fittedSize.height > size.height) {
        fittedSize = CGSizeMake((int)((fittedSize.width * size.height / MAX(fittedSize.height, 1.0f))), size.height);
    }
    
    int width = (int)fittedSize.width;
    int height = (int)fittedSize.height;
    
    int targetBytesPerRow = ((4 * (int)width) + 31) & (~31);
    uint8_t *targetMemory = (uint8_t *)malloc((int)(targetBytesPerRow * height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, width, height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    UIGraphicsPushContext(targetContext);
    
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(targetContext, CGRectMake(0, 0, width, height), image.CGImage);
    
    UIGraphicsPopContext();
    
    int bufferBytesPerRow = ((3 * (int)width) + 31) & (~31);
    uint8_t *buffer = (uint8_t *)malloc(bufferBytesPerRow * height);
    
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            uint32_t *color = ((uint32_t *)&targetMemory[y * targetBytesPerRow + x * 4]);
            
            uint32_t r = ((*color >> 16) & 0xff);
            uint32_t g = ((*color >> 8) & 0xff);
            uint32_t b = (*color & 0xff);
            
            buffer[y * bufferBytesPerRow + x * 3 + 0] = r;
            buffer[y * bufferBytesPerRow + x * 3 + 1] = g;
            buffer[y * bufferBytesPerRow + x * 3 + 2] = b;
        }
    }
    
    CGContextRelease(targetContext);
    
    free(targetMemory);
    
    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;
    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);
    
    uint8_t *outBuffer = NULL;
    unsigned long outSize = 0;
    jpeg_mem_dest(&cinfo, &outBuffer, &outSize);
    
    cinfo.image_width = (uint32_t)width;
    cinfo.image_height = (uint32_t)height;
    cinfo.input_components = 3;
    cinfo.in_color_space = JCS_RGB;
    jpeg_c_set_int_param(&cinfo, JINT_COMPRESS_PROFILE, JCP_FASTEST);
    jpeg_set_defaults(&cinfo);
    cinfo.arith_code = FALSE;
    cinfo.dct_method = JDCT_ISLOW;
    cinfo.optimize_coding = FALSE;
    jpeg_set_quality(&cinfo, 20, 1);
    jpeg_start_compress(&cinfo, 1);
    
    JSAMPROW rowPointer[1];
    while (cinfo.next_scanline < cinfo.image_height) {
        rowPointer[0] = (JSAMPROW)(buffer + cinfo.next_scanline * bufferBytesPerRow);
        jpeg_write_scanlines(&cinfo, rowPointer, 1);
    }
    
    jpeg_finish_compress(&cinfo);
    
    NSMutableData *serializedData = nil;
    
    NSData *headerPattern = getHeaderPattern();
    NSData *footerPattern = getFooterPattern();
    if (outBuffer[164] == height && outBuffer[166] == width && headerPattern != nil && footerPattern != nil) {
        outBuffer[164] = 0;
        outBuffer[166] = 0;
        
        if (memcmp(headerPattern.bytes, outBuffer, headerPattern.length) == 0) {
            if (memcmp(footerPattern.bytes, outBuffer + outSize - footerPattern.length, footerPattern.length) == 0) {
                serializedData = [[NSMutableData alloc] init];
                uint8_t version = 1;
                [serializedData appendBytes:&version length:1];
                uint8_t outWidth = (uint8_t)width;
                uint8_t outHeight = (uint8_t)height;
                [serializedData appendBytes:&outHeight length:1];
                [serializedData appendBytes:&outWidth length:1];
                unsigned long contentSize = outSize - headerPattern.length - footerPattern.length;
                [serializedData appendBytes:outBuffer + headerPattern.length length:contentSize];
            }
        }
    }
    
    jpeg_destroy_compress(&cinfo);
    
    free(buffer);
    
    return serializedData;
}
#endif

#if USE_JPEGLI
UIImage * _Nullable decompressImage(NSData * _Nonnull sourceData) {
    return [UIImage imageWithData:sourceData];
}
#else
UIImage * _Nullable decompressImage(NSData * _Nonnull sourceData) {
    long unsigned int jpegSize = sourceData.length;
    unsigned char *_compressedImage = (unsigned char *)sourceData.bytes;

    int jpegSubsamp, width, height;

    tjhandle _jpegDecompressor = tjInitDecompress();

    if (tjDecompressHeader2(_jpegDecompressor, _compressedImage, jpegSize, &width, &height, &jpegSubsamp) != 0) {
        return nil;
    }

    int sourceBytesPerRow = (3 * width + 31) & ~0x1F;
    int targetBytesPerRow = (4 * width + 31) & ~0x1F;

    unsigned char *buffer = (uint8_t *)malloc(sourceBytesPerRow * height);

    tjDecompress2(_jpegDecompressor, _compressedImage, jpegSize, buffer, width, sourceBytesPerRow, height, TJPF_RGB, TJFLAG_FASTDCT | TJFLAG_FASTUPSAMPLE);

    tjDestroy(_jpegDecompressor);

    vImage_Buffer source;
    source.width = width;
    source.height = height;
    source.rowBytes = sourceBytesPerRow;
    source.data = buffer;

    vImage_Buffer target;
    target.width = width;
    target.height = height;
    target.rowBytes = targetBytesPerRow;

    unsigned char *targetBuffer = (uint8_t *)malloc(targetBytesPerRow * height);
    target.data = targetBuffer;

    vImageConvert_RGB888toARGB8888(&source, nil, 0xff, &target, false, kvImageDoNotTile);

    free(buffer);

    vImage_Buffer permuteTarget;
    permuteTarget.width = width;
    permuteTarget.height = height;
    permuteTarget.rowBytes = targetBytesPerRow;

    unsigned char *permuteTargetBuffer = (uint8_t *)malloc(targetBytesPerRow * height);
    permuteTarget.data = permuteTargetBuffer;

    const uint8_t permuteMap[4] = {3,2,1,0};
    vImagePermuteChannels_ARGB8888(&target, &permuteTarget, permuteMap, kvImageDoNotTile);

    free(targetBuffer);

    NSData *resultData = [[NSData alloc] initWithBytesNoCopy:permuteTargetBuffer length:targetBytesPerRow * height deallocator:^(void * _Nonnull bytes, __unused NSUInteger length) {
        free(bytes);
    }];

    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)resultData);

    static CGColorSpaceRef imageColorSpace;
    static CGBitmapInfo bitmapInfo;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), YES, 0);
        UIImage *refImage = UIGraphicsGetImageFromCurrentImageContext();
        imageColorSpace = CGColorSpaceRetain(CGImageGetColorSpace(refImage.CGImage));
        bitmapInfo = CGImageGetBitmapInfo(refImage.CGImage);
        UIGraphicsEndImageContext();
    });

    CGImageRef cgImg = CGImageCreate(width, height, 8, 32, targetBytesPerRow, imageColorSpace, bitmapInfo, dataProvider, NULL, true, kCGRenderingIntentDefault);

    CGDataProviderRelease(dataProvider);

    UIImage *resultImage = [[UIImage alloc] initWithCGImage:cgImg];
    CGImageRelease(cgImg);

    return resultImage;
}
#endif
