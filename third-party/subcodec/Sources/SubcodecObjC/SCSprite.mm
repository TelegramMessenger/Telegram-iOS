// Sources/SubcodecObjC/SCSprite.mm
#import "SCSprite.h"

#include "sprite_extractor.h"
#include "sprite_encode.h"
#include "frame_writer.h"
#include "types.h"

#include <memory>
#include <vector>
#include <optional>

using namespace subcodec;

static NSError* makeError(NSString* msg) {
    return [NSError errorWithDomain:@"SCSprite" code:-1
                           userInfo:@{NSLocalizedDescriptionKey: msg}];
}

@implementation SCSprite {
    // Extractor mode
    std::optional<SpriteExtractor> _extractor;

    // Encoder mode
    std::optional<SpriteEncoder> _encoder;
    std::vector<std::vector<uint8_t>> _nalFrames;
    int _paddedWidth;
    int _paddedHeight;
    int _qp;
}

+ (nullable SCSprite *)extractorWithSpriteSize:(int)size
                                            qp:(int)qp
                                    outputPath:(NSString *)path
                                         error:(NSError **)error {
    SpriteExtractor::Params params;
    params.sprite_size = size;
    params.qp = qp;

    auto result = SpriteExtractor::create(params, path.UTF8String);
    if (!result) {
        if (error) *error = makeError(@"Failed to create SpriteExtractor");
        return nil;
    }

    SCSprite* sprite = [[SCSprite alloc] init];
    sprite->_extractor.emplace(std::move(*result));
    return sprite;
}

- (BOOL)addFrameY:(NSData *)y yStride:(int)ys
               cb:(NSData *)cb cbStride:(int)cbs
               cr:(NSData *)cr crStride:(int)crs
            alpha:(NSData *)alpha alphaStride:(int)as
            error:(NSError **)error {
    if (!_extractor) {
        if (error) *error = makeError(@"Not in extractor mode");
        return NO;
    }

    auto result = _extractor->add_frame(
        (const uint8_t*)y.bytes, ys,
        (const uint8_t*)cb.bytes, cbs,
        (const uint8_t*)cr.bytes, crs,
        (const uint8_t*)alpha.bytes, as);

    if (!result) {
        if (error) *error = makeError(@"add_frame failed");
        return NO;
    }
    return YES;
}

- (BOOL)finalizeExtraction:(NSError **)error {
    if (!_extractor) {
        if (error) *error = makeError(@"Not in extractor mode");
        return NO;
    }
    auto result = _extractor->finalize();
    if (!result) {
        if (error) *error = makeError(@"finalize failed");
        return NO;
    }
    return YES;
}

// Encoder path
+ (nullable SCSprite *)encoderWithWidth:(int)width
                                 height:(int)height
                                     qp:(int)qp
                                  error:(NSError **)error {
    SpriteEncoder::Params params;
    params.width = width;
    params.height = height;
    params.qp = qp;

    auto result = SpriteEncoder::create(params);
    if (!result) {
        if (error) *error = makeError(@"Failed to create SpriteEncoder");
        return nil;
    }

    SCSprite* sprite = [[SCSprite alloc] init];
    sprite->_encoder.emplace(std::move(*result));
    sprite->_paddedWidth = width + 2 * 16;
    sprite->_paddedHeight = height + 2 * 16;
    sprite->_qp = qp;
    return sprite;
}

- (BOOL)encodeFrameY:(NSData *)y yStride:(int)ys
                  cb:(NSData *)cb cbStride:(int)cbs
                  cr:(NSData *)cr crStride:(int)crs
          frameIndex:(int)idx
               error:(NSError **)error {
    if (!_encoder) {
        if (error) *error = makeError(@"Not in encoder mode");
        return NO;
    }

    // Create opaque alpha buffer for encoder (no alpha source in ObjC wrapper yet)
    std::vector<uint8_t> alpha_buf(_paddedWidth * _paddedHeight, 255);

    std::vector<uint8_t> nal;
    auto result = _encoder->encode(
        (const uint8_t*)y.bytes, ys,
        (const uint8_t*)cb.bytes, cbs,
        (const uint8_t*)cr.bytes, crs,
        alpha_buf.data(), _paddedWidth,
        idx, &nal);

    if (!result) {
        if (error) *error = makeError(@"encode failed");
        return NO;
    }

    _nalFrames.push_back(std::move(nal));
    return YES;
}

- (nullable NSData *)buildStreamWithError:(NSError **)error {
    if (!_encoder) {
        if (error) *error = makeError(@"Not in encoder mode");
        return nil;
    }

    int paddedMbs = _paddedWidth / 16;
    FrameParams fp;
    fp.width_mbs = paddedMbs * 2;  // double-wide canvas (color + alpha)
    fp.height_mbs = paddedMbs;
    fp.qp = _qp;
    fp.log2_max_frame_num = 4;

    uint8_t hdr[128];
    size_t hdr_size = frame_writer::write_headers({hdr, sizeof(hdr)}, fp);

    size_t total = hdr_size;
    for (auto& nal : _nalFrames) total += nal.size();

    NSMutableData* stream = [NSMutableData dataWithLength:total];
    uint8_t* dst = (uint8_t*)stream.mutableBytes;
    memcpy(dst, hdr, hdr_size);
    size_t off = hdr_size;
    for (auto& nal : _nalFrames) {
        memcpy(dst + off, nal.data(), nal.size());
        off += nal.size();
    }

    return stream;
}

@end
