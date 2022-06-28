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

void combineYUVAPlanesIntoARBB(uint8_t *argb, uint8_t const *inY, uint8_t const *inU, uint8_t const *inV, uint8_t const *inA, int width, int height, int bytesPerRow) {
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
}
