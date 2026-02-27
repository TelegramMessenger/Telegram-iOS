#import <Crc32/Crc32.h>

#import <zlib.h>

uint32_t Crc32(const void *bytes, int length) {
    return (uint32_t)crc32(0, bytes, (uInt)length);
}
