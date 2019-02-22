#import "ID3Artwork.h"

const uint8_t ID3v2[5] = {0x49, 0x44, 0x33, 0x02, 0x00};
const uint8_t ID3v3[5] = {0x49, 0x44, 0x33, 0x03, 0x00};
const NSUInteger ID3VersionOffset = 3;
const NSUInteger ID3SizeOffset = 6;
const NSUInteger ID3TagOffset = 10;
const NSUInteger ID3ArtOffset = 12;

const NSUInteger ID3v2FrameOffset = 6;
const NSUInteger ID3v3FrameOffset = 10;

const uint8_t ID3v2Artwork[3] = {0x50, 0x49, 0x43};
const uint8_t ID3v3Artwork[4] = {0x41, 0x50, 0x49, 0x43};

const uint8_t JPGMagic[3] = {0xff, 0xd8, 0xff};
const uint8_t PNGMagic[4] = {0x89, 0x50, 0x4e, 0x47};


uint32_t frameOffsetForVersion(uint8_t version) {
    return version == 2 ? ID3v2FrameOffset : ID3v3FrameOffset;
}

uint32_t frameSizeForBytes(const uint8_t *framePtr, uint8_t version) {
    uint8_t offset = version == 2 ? 2 : 4;
    uint32_t size = CFSwapInt32HostToBig(*(uint32_t *)(framePtr + offset));
    
    if (version == 2) {
        size &= 0x00FFFFFF;
    }
    
    return size + frameOffsetForVersion(version);
}

bool isArtworkFrame(const uint8_t *framePtr, uint8_t version) {
    if (version == 2) {
        return memcmp(framePtr, ID3v2Artwork, 3) == 0;
    }
    
    return memcmp(framePtr, ID3v3Artwork, 4) == 0;
}

NSData * _Nullable albumArtworkData(NSData * _Nonnull data) {
    if (data.length < 4) {
        return nil;
    }
    
    const uint8_t *bytes = data.bytes;
    if (!(memcmp(bytes, ID3v2, 5) == 0 || memcmp(bytes, ID3v3, 5) == 0)) {
        return nil;
    }
    
    uint8_t version = bytes[ID3VersionOffset];
    uint32_t size = CFSwapInt32HostToBig(*(const uint32_t *)(bytes + ID3SizeOffset));
    uint32_t b1 = (size & 0x7F000000) >> 3;
    uint32_t b2 = (size & 0x007F0000) >> 2;
    uint32_t b3 = (size & 0x00007F00) >> 1;
    uint32_t b4 =  size & 0x0000007F;
    size = b1 + b2 + b3 + b4;
    
    const uint8_t *ptr = bytes + ID3TagOffset;
    
    uint32_t pos = 0;
    while (pos < size) {
        const uint8_t * const frameBytes = ptr + pos;
        if (ID3TagOffset + pos + 4 >= data.length) {
            return nil;
        }
        uint32_t frameSize = frameSizeForBytes(frameBytes, version);
        if (ID3TagOffset + pos + frameSize >= data.length) {
            return nil;
        }
        
        if (isArtworkFrame(frameBytes, version)) {
            uint32_t frameOffset = frameOffsetForVersion(version);
            const uint8_t *ptr = frameBytes + frameOffset;
            uint32_t start = ID3TagOffset + pos + frameOffset;
            
            bool isJpg = false;
            uint32_t imageOffset = UINT32_MAX;
            for (uint32_t i = 0; i < frameSize - 4; i++) {
                if (memcmp(ptr + i, JPGMagic, 3) == 0) {
                    imageOffset = i;
                    isJpg = true;
                    break;
                } else if (memcmp(ptr + i, PNGMagic, 4) == 0) {
                    imageOffset = i;
                    break;
                }
            }
            
            if (imageOffset != UINT32_MAX) {
                if (isJpg) {
                    NSMutableData *jpgData = [[NSMutableData alloc] initWithCapacity:frameSize + 1024];
                    uint8_t previousByte = 0xff;
                    uint32_t skippedBytes = 0;
                    
                    for (uint32_t i = 0; i < frameSize - imageOffset + skippedBytes; i++) {
                        uint32_t offset = imageOffset + i;
                        if (start + offset >= data.length) {
                            return nil;
                        }
                        uint8_t byte = (uint8_t)ptr[offset];
                        [jpgData appendBytes:&byte length:1];
                        if (byte == 0xd9 && previousByte == 0xff) {
                            break;
                        }
                        previousByte = byte;
                    }
                    return jpgData;
                }
                else {
                    if (start + frameSize > data.length) {
                        return nil;
                    }
                    return [[NSData alloc] initWithBytes:ptr + imageOffset length:frameSize - imageOffset];
                }
            }
        }
        else if (frameBytes[0] == 0x00 && frameBytes[1] == 0x00 && frameBytes[2] == 0x00) {
            break;
        }
        
        pos += frameSize;
    }
    
    return nil;
}
