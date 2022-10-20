#import <ImageDCT/YuvConversion.h>

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

static uint8_t permuteMap[4] = { 3, 2, 1, 0};

void splitRGBAIntoYUVAPlanes(uint8_t const *argb, uint8_t *outY, uint8_t *outU, uint8_t *outV, uint8_t *outA, int width, int height, int bytesPerRow) {
    static vImage_ARGBToYpCbCr info;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        vImage_YpCbCrPixelRange pixelRange = (vImage_YpCbCrPixelRange){ 0, 128, 255, 255, 255, 1, 255, 0 };
        vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2, &pixelRange, &info, kvImageARGB8888, kvImage420Yp8_Cb8_Cr8, 0);
    });
    
    vImage_Error error = kvImageNoError;
    
    vImage_Buffer src;
    src.data = (void *)argb;
    src.width = width;
    src.height = height;
    src.rowBytes = bytesPerRow;
    
    vImage_Buffer destYp;
    destYp.data = outY;
    destYp.width = width;
    destYp.height = height;
    destYp.rowBytes = width;
    
    vImage_Buffer destCr;
    destCr.data = outU;
    destCr.width = width / 2;
    destCr.height = height / 2;
    destCr.rowBytes = width / 2;
    
    vImage_Buffer destCb;
    destCb.data = outV;
    destCb.width = width / 2;
    destCb.height = height / 2;
    destCb.rowBytes = width / 2;
    
    vImage_Buffer destA;
    destA.data = outA;
    destA.width = width;
    destA.height = height;
    destA.rowBytes = width;
    
    error = vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(&src, &destYp, &destCb, &destCr, &info, permuteMap, kvImageDoNotTile);
    if (error != kvImageNoError) {
        return;
    }
    
    vImageExtractChannel_ARGB8888(&src, &destA, 3, kvImageDoNotTile);
}

void combineYUVAPlanesIntoARGB(uint8_t *argb, uint8_t const *inY, uint8_t const *inU, uint8_t const *inV, uint8_t const *inA, int width, int height, int bytesPerRow) {
    static vImage_YpCbCrToARGB info;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        vImage_YpCbCrPixelRange pixelRange = (vImage_YpCbCrPixelRange){ 0, 128, 255, 255, 255, 1, 255, 0 };
        vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_709_2, &pixelRange, &info, kvImage420Yp8_Cb8_Cr8, kvImageARGB8888, 0);
    });
    
    vImage_Error error = kvImageNoError;
    
    vImage_Buffer destArgb;
    destArgb.data = (void *)argb;
    destArgb.width = width;
    destArgb.height = height;
    destArgb.rowBytes = bytesPerRow;
    
    vImage_Buffer srcYp;
    srcYp.data = (void *)inY;
    srcYp.width = width;
    srcYp.height = height;
    srcYp.rowBytes = width;
    
    vImage_Buffer srcCr;
    srcCr.data = (void *)inU;
    srcCr.width = width / 2;
    srcCr.height = height / 2;
    srcCr.rowBytes = width / 2;
    
    vImage_Buffer srcCb;
    srcCb.data = (void *)inV;
    srcCb.width = width / 2;
    srcCb.height = height / 2;
    srcCb.rowBytes = width / 2;
    
    vImage_Buffer srcA;
    srcA.data = (void *)inA;
    srcA.width = width;
    srcA.height = height;
    srcA.rowBytes = width;
    
    error = vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(&srcYp, &srcCb, &srcCr, &destArgb, &info, permuteMap, 255, kvImageDoNotTile);
    error = vImageOverwriteChannels_ARGB8888(&srcA, &destArgb, &destArgb, 1 << 0, kvImageDoNotTile);
    
    if (error != kvImageNoError) {
    }
    
    //error = vImageOverwriteChannels_ARGB8888(&srcYp, &destArgb, &destArgb, 1 << 1, kvImageDoNotTile);
    //error = vImageOverwriteChannels_ARGB8888(&srcYp, &destArgb, &destArgb, 1 << 2, kvImageDoNotTile);
    //error = vImageOverwriteChannels_ARGB8888(&srcYp, &destArgb, &destArgb, 1 << 3, kvImageDoNotTile);
}

void scaleImagePlane(uint8_t *outPlane, int outWidth, int outHeight, int outBytesPerRow, uint8_t const *inPlane, int inWidth, int inHeight, int inBytesPerRow) {
    vImage_Buffer src;
    src.data = (void *)inPlane;
    src.width = inWidth;
    src.height = inHeight;
    src.rowBytes = inBytesPerRow;
    
    vImage_Buffer dst;
    dst.data = (void *)outPlane;
    dst.width = outWidth;
    dst.height = outHeight;
    dst.rowBytes = outBytesPerRow;
    
    vImageScale_Planar8(&src, &dst, nil, kvImageDoNotTile);
}

void convertUInt8toInt16(uint8_t const *source, int16_t *dest, int length) {
#if defined(__aarch64__)
    
#if DEBUG
    assert(!((intptr_t)source % sizeof(uint64_t)));
    assert(!((intptr_t)dest % sizeof(uint64_t)));
#endif

    for (int i = 0; i < length; i += 8 * 4) {
        #pragma unroll
        for (int j = 0; j < 4; j++) {
            uint8x8_t lhs8 = vld1_u8(&source[i + j * 8]);
            int16x8_t lhs = vreinterpretq_s16_u16(vmovl_u8(lhs8));
            
            vst1q_s16(&dest[i + j * 8], lhs);
        }
    }
    if (length % (8 * 4) != 0) {
        for (int i = length - (length % (8 * 4)); i < length; i++) {
            dest[i] = (int16_t)source[i];
        }
    }
#else
    for (int i = 0; i < length; i++) {
        dest[i] = (int16_t)source[i];
    }
#endif
}

void convertInt16toUInt8(int16_t const *source, uint8_t *dest, int length) {
#if defined(__aarch64__)
    for (int i = 0; i < length; i += 8) {
        int16x8_t lhs16 = vld1q_s16(&source[i]);
        int8x8_t lhs = vqmovun_s16(lhs16);
        
        vst1_u8(&dest[i], lhs);
    }
    if (length % 8 != 0) {
        for (int i = length - (length % 8); i < length; i++) {
            int16_t result = source[i];
            if (result < 0) {
                result = 0;
            }
            if (result > 255) {
                result = 255;
            }
            dest[i] = (int8_t)result;
        }
    }
#else
    for (int i = 0; i < length; i++) {
        int16_t result = source[i];
        if (result < 0) {
            result = 0;
        }
        if (result > 255) {
            result = 255;
        }
        dest[i] = (int8_t)result;
    }
#endif
}

void subtractArraysInt16(int16_t const *a, int16_t const *b, int16_t *dest, int length) {
#if defined(__aarch64__)
    for (int i = 0; i < length; i += 8) {
        int16x8_t lhs = vld1q_s16((int16_t *)&a[i]);
        int16x8_t rhs = vld1q_s16((int16_t *)&b[i]);
        int16x8_t result = vsubq_s16(lhs, rhs);
        vst1q_s16((int16_t *)&dest[i], result);
    }
    if (length % 8 != 0) {
        for (int i = length - (length % 8); i < length; i++) {
            dest[i] = a[i] - b[i];
        }
    }
#else
    for (int i = 0; i < length; i++) {
        dest[i] = a[i] - b[i];
    }
#endif
}

void addArraysInt16(int16_t const *a, int16_t const *b, int16_t *dest, int length) {
#if defined(__aarch64__)
    for (int i = 0; i < length; i += 8 * 4) {
        #pragma unroll
        for (int j = 0; j < 4; j++) {
            int16x8_t lhs = vld1q_s16((int16_t *)&a[i + j * 8]);
            int16x8_t rhs = vld1q_s16((int16_t *)&b[i + j * 8]);
            int16x8_t result = vaddq_s16(lhs, rhs);
            vst1q_s16((int16_t *)&dest[i + j * 8], result);
        }
    }
    if (length % (8 * 4) != 0) {
        for (int i = length - (length % (8 * 4)); i < length; i++) {
            dest[i] = a[i] - b[i];
        }
    }
#else
    for (int i = 0; i < length; i++) {
        dest[i] = a[i] - b[i];
    }
#endif
}

void subtractArraysUInt8Int16(uint8_t const *a, int16_t const *b, uint8_t *dest, int length) {
#if defined(__aarch64__)
    for (int i = 0; i < length; i += 8) {
        uint8x8_t lhs8 = vld1_u8(&a[i]);
        int16x8_t lhs = vreinterpretq_s16_u16(vmovl_u8(lhs8));
        
        int16x8_t rhs = vld1q_s16((int16_t *)&b[i]);
        int16x8_t result = vsubq_s16(lhs, rhs);
        
        uint8x8_t result8 = vqmovun_s16(result);
        vst1_u8(&dest[i], result8);
    }
    if (length % 8 != 0) {
        for (int i = length - (length % 8); i < length; i++) {
            int16_t result = ((int16_t)a[i]) - b[i];
            if (result < 0) {
                result = 0;
            }
            if (result > 255) {
                result = 255;
            }
            dest[i] = (int8_t)result;
        }
    }
#else
    for (int i = 0; i < length; i++) {
        int16_t result = ((int16_t)a[i]) - b[i];
        if (result < 0) {
            result = 0;
        }
        if (result > 255) {
            result = 255;
        }
        dest[i] = (int8_t)result;
    }
#endif
}

void addArraysUInt8Int16(uint8_t const *a, int16_t const *b, uint8_t *dest, int length) {
#if defined(__aarch64__)
    for (int i = 0; i < length; i += 8) {
        uint8x8_t lhs8 = vld1_u8(&a[i]);
        int16x8_t lhs = vreinterpretq_s16_u16(vmovl_u8(lhs8));
        
        int16x8_t rhs = vld1q_s16((int16_t *)&b[i]);
        int16x8_t result = vaddq_s16(lhs, rhs);
        
        uint8x8_t result8 = vqmovun_s16(result);
        vst1_u8(&dest[i], result8);
    }
    if (length % 8 != 0) {
        for (int i = length - (length % 8); i < length; i++) {
            int16_t result = ((int16_t)a[i]) + b[i];
            if (result < 0) {
                result = 0;
            }
            if (result > 255) {
                result = 255;
            }
            dest[i] = (int8_t)result;
        }
    }
#else
    for (int i = 0; i < length; i++) {
        int16_t result = ((int16_t)a[i]) + b[i];
        if (result < 0) {
            result = 0;
        }
        if (result > 255) {
            result = 255;
        }
        dest[i] = (int8_t)result;
    }
#endif
}
