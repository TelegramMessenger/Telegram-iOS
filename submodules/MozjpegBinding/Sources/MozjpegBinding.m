#import <MozjpegBinding/MozjpegBinding.h>

#import <mozjpeg/turbojpeg.h>
#import <mozjpeg/jpeglib.h>

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
    
    const uint8_t *dataBytes = data.bytes;
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

NSData * _Nullable compressJPEGData(UIImage * _Nonnull sourceImage) {
    int width = (int)(sourceImage.size.width * sourceImage.scale);
    int height = (int)(sourceImage.size.height * sourceImage.scale);
    
    int targetBytesPerRow = ((4 * (int)width) + 15) & (~15);
    uint8_t *targetMemory = malloc((int)(targetBytesPerRow * height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, width, height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    UIGraphicsPushContext(targetContext);
    
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(targetContext, CGRectMake(0, 0, width, height), sourceImage.CGImage);
    
    UIGraphicsPopContext();
    
    int bufferBytesPerRow = ((3 * (int)width) + 15) & (~15);
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
    jpeg_c_set_int_param(&cinfo, JINT_COMPRESS_PROFILE, JCP_FASTEST);
    jpeg_set_defaults(&cinfo);
    cinfo.arith_code = FALSE;
    cinfo.dct_method = JDCT_ISLOW;
    cinfo.optimize_coding = TRUE;
    jpeg_set_quality(&cinfo, 78, 1);
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

NSData * _Nullable compressMiniThumbnail(UIImage * _Nonnull image) {
    CGSize size = CGSizeMake(40.0f, 40.0f);
    CGSize fittedSize = image.size;
    if (fittedSize.width > size.width) {
        fittedSize = CGSizeMake(size.width, (int)((fittedSize.height * size.width / MAX(fittedSize.width, 1.0f))));
    }
    if (fittedSize.height > size.height) {
        fittedSize = CGSizeMake((int)((fittedSize.width * size.height / MAX(fittedSize.height, 1.0f))), size.height);
    }
    
    int width = (int)fittedSize.width;
    int height = (int)fittedSize.height;
    
    int targetBytesPerRow = ((4 * (int)width) + 15) & (~15);
    uint8_t *targetMemory = malloc((int)(targetBytesPerRow * height));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef targetContext = CGBitmapContextCreate(targetMemory, width, height, 8, targetBytesPerRow, colorSpace, bitmapInfo);
    
    UIGraphicsPushContext(targetContext);
    
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(targetContext, CGRectMake(0, 0, width, height), image.CGImage);
    
    UIGraphicsPopContext();
    
    int bufferBytesPerRow = ((3 * (int)width) + 15) & (~15);
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
