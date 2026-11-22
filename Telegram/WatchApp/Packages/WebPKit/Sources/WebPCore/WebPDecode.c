#include "WebPCore/WebPDecode.h"
#include "webp/decode.h"
#include <stdlib.h>

int webp_kit_decode_rgba(
    const uint8_t *data,
    size_t data_size,
    uint8_t **out_data,
    int *out_width,
    int *out_height
) {
    if (data == NULL || data_size == 0 || out_data == NULL ||
        out_width == NULL || out_height == NULL) {
        return 0;
    }
    int width = 0;
    int height = 0;
    uint8_t *decoded = WebPDecodeRGBA(data, data_size, &width, &height);
    if (decoded == NULL) {
        return 0;
    }
    *out_data = decoded;
    *out_width = width;
    *out_height = height;
    return 1;
}

void webp_kit_free(uint8_t *buffer) {
    if (buffer != NULL) {
        WebPFree(buffer);
    }
}
