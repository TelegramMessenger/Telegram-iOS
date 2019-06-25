#import "TextureCompression.h"
#import "BC1Compression.h"
#import "PvrTcEncoder.h"
#import "PvrTcDecoder.h"
#import "RgbaBitmap.h"

void compressRGBAToBC1(uint8_t const * _Nonnull argb, int width, int height, uint8_t * _Nonnull bc1) {
    Javelin::RgbaBitmap bitmap(width, height);
    uint8_t *data = (uint8_t *)bitmap.GetData();
    for (int i = 0; i < width * height; i++) {
        data[i * 4 + 0] = argb[i * 4 + 0];
        data[i * 4 + 1] = argb[i * 4 + 1];
        data[i * 4 + 2] = argb[i * 4 + 2];
        data[i * 4 + 3] = argb[i * 4 + 3];
    }
    Javelin::PvrTcEncoder::EncodeRgb4Bpp(bc1, bitmap);
}

void decompressBC1ToRGBA(uint8_t const * _Nonnull bc1, int width, int height, uint8_t * _Nonnull argb) {
    uint8_t *data = (uint8_t *)malloc(width * height * 3);
    Javelin::PvrTcDecoder::DecodeRgb4Bpp((Javelin::ColorRgba<unsigned char> *)data, Javelin::Point2<int>(width, height), bc1);
    for (int i = 0; i < width * height; i++) {
        uint8_t r = data[i * 3 + 0];
        uint8_t g = data[i * 3 + 1];
        uint8_t b = data[i * 3 + 2];
        argb[i * 4 + 3] = 255;
        argb[i * 4 + 2] = b;
        argb[i * 4 + 1] = g;
        argb[i * 4 + 0] = r;
    }
    free(data);
}

void compressRGBAToETC2(uint8_t const * _Nonnull argb, int width, int height, uint8_t * _Nonnull etc2) {
    
}
