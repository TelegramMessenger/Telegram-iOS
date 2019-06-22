#import "YUV.h"

void encodeRGBAToBRGR422A(uint8_t *bgrg422, uint8_t *a, uint8_t const *argb, int width, int height) {
    int i, j;
    int lineWidth = width * 2;
    for (j = 0; j < height; j++) {
        for (i = 0; i < width; i += 2) {
            int A1 = argb[(j * width + i) * 4 + 0];
            int R1 = argb[(j * width + i) * 4 + 3];
            int G1 = argb[(j * width + i) * 4 + 2];
            int B1 = argb[(j * width + i) * 4 + 1];
            
            int A2 = argb[(j * width + i) * 4 + 4];
            int R2 = argb[(j * width + i) * 4 + 7];
            int G2 = argb[(j * width + i) * 4 + 6];
            int B2 = argb[(j * width + i) * 4 + 5];
            
            bgrg422[j * lineWidth + (i / 2) * 4 + 0] = (uint8_t)((B1 + B2) >> 1);
            bgrg422[j * lineWidth + (i / 2) * 4 + 1] = G1;
            bgrg422[j * lineWidth + (i / 2) * 4 + 2] = (uint8_t)((R1 + R2) >> 1);
            bgrg422[j * lineWidth + (i / 2) * 4 + 3] = G2;
            
            a[j * width + i + 0] = A1;
            a[j * width + i + 1] = A2;
        }
    }
}

void encodeBRGR422AToRGBA(uint8_t const * _Nonnull bgrg422, uint8_t const * _Nonnull const a, uint8_t * _Nonnull argb, int width, int height) {
    int i, j;
    int lineWidth = width * 2;
    for (j = 0; j < height; j++) {
        for (i = 0; i < width; i += 2) {
            argb[(j * width + i) * 4 + 0] = a[j * width + i + 0];
            argb[(j * width + i) * 4 + 3] = bgrg422[j * lineWidth + (i / 2) * 4 + 2];
            argb[(j * width + i) * 4 + 2] = bgrg422[j * lineWidth + (i / 2) * 4 + 1];
            argb[(j * width + i) * 4 + 1] = bgrg422[j * lineWidth + (i / 2) * 4 + 0];
            
            argb[(j * width + i) * 4 + 4] = a[j * width + i + 1];
            argb[(j * width + i) * 4 + 7] = bgrg422[j * lineWidth + (i / 2) * 4 + 2];
            argb[(j * width + i) * 4 + 6] = bgrg422[j * lineWidth + (i / 2) * 4 + 3];
            argb[(j * width + i) * 4 + 5] = bgrg422[j * lineWidth + (i / 2) * 4 + 0];
        }
    }
}

NSData * _Nonnull encodeSparseBuffer(uint8_t const * _Nonnull bytes, int length) {
    NSMutableData *result = [[NSMutableData alloc] init];
    int offset = 0;
    int currentStart = 0;
    int currentType = 0;
    while (offset != length) {
        if (bytes[offset] == 0) {
            if (currentType != 0) {
                
            }
        } else {
            
        }
        offset += 1;
    }
    return result;
}

void decodeSparseeBuffer(uint8_t * _Nonnull bytes, uint8_t const * _Nonnull buffer) {
    
}
