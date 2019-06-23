#import "TextureCompression.h"
#import "BC1Compression.h"

void compressRGBAToBC1(uint8_t const * _Nonnull argb, int width, int height, uint8_t * _Nonnull bc1) {
    DTX1CompressorDecompressor::BC1Compression compression;
    DTX1CompressorDecompressor::BMPImage image;
    image.InitWithData((unsigned char *)argb, width, height);
    image.m_ownData = false;
    DTX1CompressorDecompressor::BC1DDSImage ddsImage;
    compression.Compress(image, ddsImage);
    int numBlocks = width * height / (4 * 4);
    memcpy(bc1, ddsImage.GetData(), numBlocks * 8);
}
