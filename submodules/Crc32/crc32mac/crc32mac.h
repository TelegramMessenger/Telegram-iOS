#import <Cocoa/Cocoa.h>

//! Project version number for crc32mac.
FOUNDATION_EXPORT double crc32macVersionNumber;

//! Project version string for crc32mac.
FOUNDATION_EXPORT const unsigned char crc32macVersionString[];

uint32_t Crc32(const void *bytes, int length);
