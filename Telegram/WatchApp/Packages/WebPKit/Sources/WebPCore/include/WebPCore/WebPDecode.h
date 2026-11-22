#ifndef WEBP_KIT_DECODE_H
#define WEBP_KIT_DECODE_H

#include <stddef.h>
#include <stdint.h>

/// Decodes a WebP buffer into RGBA8888 pixels.
/// Returns 1 on success, 0 on failure. On success, `*out_data` points at a
/// heap buffer the caller must free with `webp_kit_free` and `*out_width` /
/// `*out_height` carry the pixel dimensions.
int webp_kit_decode_rgba(
    const uint8_t *data,
    size_t data_size,
    uint8_t **out_data,
    int *out_width,
    int *out_height
);

/// Frees a buffer returned by `webp_kit_decode_rgba`.
void webp_kit_free(uint8_t *buffer);

#endif
