#import <YuvConversion/YUV.h>
#import <Accelerate/Accelerate.h>

void encodeRGBAToYUVA(uint8_t *yuva, uint8_t const *argb, int width, int height, int bytesPerRow) {
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
    
    uint8_t permuteMap[4] = {3, 2, 1, 0};
    error = vImagePermuteChannels_ARGB8888(&src, &src, permuteMap, kvImageDoNotTile);
    
    error = vImageUnpremultiplyData_ARGB8888(&src, &src, kvImageDoNotTile);
    
    uint8_t *alpha = yuva + width * height * 2;
    int i = 0;
    for (int y = 0; y < height; y += 1) {
        uint8_t const *argbRow = argb + y * bytesPerRow;
        for (int x = 0; x < width; x += 2) {
            uint8_t a0 = (argbRow[x * 4 + 0] >> 4) << 4;
            uint8_t a1 = (argbRow[(x + 1) * 4 + 0] >> 4) << 4;
            alpha[i / 2] = (a0 & (0xf0U)) | ((a1 & (0xf0U)) >> 4);
            i += 2;
        }
    }
    
    vImage_Buffer destYp;
    destYp.data = (void *)(yuva + 0);
    destYp.width = width;
    destYp.height = height;
    destYp.rowBytes = width;
    
    vImage_Buffer destCbCr;
    destCbCr.data = (void *)(yuva + width * height * 1);
    destCbCr.width = width;
    destCbCr.height = height;
    destCbCr.rowBytes = width;
    
    error = vImageConvert_ARGB8888To420Yp8_CbCr8(&src, &destYp, &destCbCr, &info, NULL, kvImageDoNotTile);
    if (error != kvImageNoError) {
        return;
    }
}

void decodeYUVAToRGBA(uint8_t const *yuva, uint8_t *argb, int width, int height, int bytesPerRow) {
    static vImage_YpCbCrToARGB info;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        vImage_YpCbCrPixelRange pixelRange = (vImage_YpCbCrPixelRange){ 0, 128, 255, 255, 255, 1, 255, 0 };
        vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_709_2, &pixelRange, &info, kvImage420Yp8_Cb8_Cr8, kvImageARGB8888, 0);
    });
    
    vImage_Error error = kvImageNoError;
    
    vImage_Buffer srcYp;
    srcYp.data = (void *)(yuva + 0);
    srcYp.width = width;
    srcYp.height = height;
    srcYp.rowBytes = width * 1;
    
    vImage_Buffer srcCbCr;
    srcCbCr.data = (void *)(yuva + width * height * 1);
    srcCbCr.width = width;
    srcCbCr.height = height;
    srcCbCr.rowBytes = width * 1;
    
    vImage_Buffer dest;
    dest.data = (void *)argb;
    dest.width = width;
    dest.height = height;
    dest.rowBytes = bytesPerRow;
    
    error = vImageConvert_420Yp8_CbCr8ToARGB8888(&srcYp, &srcCbCr, &dest, &info, NULL, 0xff, kvImageDoNotTile);
    
    uint8_t const *alpha = yuva + (width * height * 1 + width * height * 1);
    int i = 0;
    for (int y = 0; y < height; y += 1) {
        uint8_t *argbRow = argb + y * bytesPerRow;
        for (int x = 0; x < width; x += 2) {
            uint8_t a = alpha[i / 2];
            uint8_t a1 = (a & (0xf0U));
            uint8_t a2 = ((a & (0x0fU)) << 4);
            argbRow[x * 4 + 0] = a1 | (a1 >> 4);
            argbRow[(x + 1) * 4 + 0] = a2 | (a2 >> 4);
            i += 2;
        }
    }
    
    error = vImagePremultiplyData_ARGB8888(&dest, &dest, kvImageDoNotTile);
    
    uint8_t permuteMap[4] = {3, 2, 1, 0};
    error = vImagePermuteChannels_ARGB8888(&dest, &dest, permuteMap, kvImageDoNotTile);
    
    if (error != kvImageNoError) {
        return;
    }
}
