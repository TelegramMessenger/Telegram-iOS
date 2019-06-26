#ifndef ASTC_COMPRESS_TEXTURE_H_
#define ASTC_COMPRESS_TEXTURE_H_

#include <cstdint>

/**
 * Compress an texture with the ASTC format.
 *
 * @param src The source data, width*height*4 bytes with BGRA ordering.
 * @param dst The output, width*height bytes.
 * @param width The width of the input texture.
 * @param height The height of the input texture.
 */
void compress_texture(const uint8_t* src, uint8_t* dst, int width, int height);

#endif  // ASTC_COMPRESS_TEXTURE_H_
