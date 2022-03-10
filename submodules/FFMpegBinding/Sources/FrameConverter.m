#import <FFMpegBinding/FrameConverter.h>

void fillDstPlane(uint8_t * _Nonnull dstPlane, uint8_t * _Nonnull srcPlane1, uint8_t * _Nonnull srcPlane2, size_t srcPlaneSize) {
    for (size_t i = 0; i < srcPlaneSize; i++){
        dstPlane[2 * i] = srcPlane1[i];
        dstPlane[2 * i + 1] = srcPlane2[i];
    }
}
