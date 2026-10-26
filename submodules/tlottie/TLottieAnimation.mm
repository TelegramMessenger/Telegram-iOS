#import <TLottieBinding/TLottieAnimation.h>

#include <vector>

extern "C" {
#include "tlottie.h"
}

@implementation TLottieAnimation {
    TLottieInstance *_instance;
    std::vector<uint32_t> _scratch;
}

- (instancetype _Nullable)initWithData:(NSData * _Nonnull)data
                          fitzModifier:(TLottieFitzModifier)fitzModifier
                     colorReplacements:(NSDictionary * _Nullable)colorReplacements {
    self = [super init];
    if (self != nil) {
        uint32_t modifier = TLOTTIE_FITZ_NONE;
        switch (fitzModifier) {
            case TLottieFitzModifierNone: modifier = TLOTTIE_FITZ_NONE; break;
            case TLottieFitzModifierType12: modifier = TLOTTIE_FITZ_TYPE_12; break;
            case TLottieFitzModifierType3: modifier = TLOTTIE_FITZ_TYPE_3; break;
            case TLottieFitzModifierType4: modifier = TLOTTIE_FITZ_TYPE_4; break;
            case TLottieFitzModifierType5: modifier = TLOTTIE_FITZ_TYPE_5; break;
            case TLottieFitzModifierType6: modifier = TLOTTIE_FITZ_TYPE_6; break;
        }

        std::vector<TLottieColorReplacement> replacements;
        if (colorReplacements != nil) {
            for (NSNumber *color in colorReplacements.allKeys) {
                NSNumber *replacement = colorReplacements[color];
                TLottieColorReplacement item;
                item.source_color = color.unsignedIntValue;
                item.target_color = replacement.unsignedIntValue;
                replacements.push_back(item);
            }
        }

        // TLOTTIE_CHANNEL_BGRA gives 0xAARRGGBB words, which is what
        // DrawingContext's premultiplied-first little-endian bitmap info
        // describes. The default, TLOTTIE_CHANNEL_RGBA, would swap red and blue
        // everywhere and fail in no other way.
        _instance = tlottie_new_with_options(
            (const uint8_t *)data.bytes,
            (size_t)data.length,
            modifier,
            nullptr,
            0,
            replacements.empty() ? nullptr : replacements.data(),
            replacements.size(),
            TLOTTIE_CHANNEL_BGRA);
        if (_instance == nullptr) {
            return nil;
        }

        int32_t frameCount = (int32_t)tlottie_frame_count(_instance);
        _frameCount = MAX(1, frameCount);

        float rawFrameRate = tlottie_frame_rate(_instance);
        _frameRate = MAX(1, (int32_t)rawFrameRate);

        _duration = rawFrameRate > 0.0f ? (double)frameCount / (double)rawFrameRate : 0.0;

        uint32_t width = tlottie_width(_instance);
        uint32_t height = tlottie_height(_instance);
        _dimensions = CGSizeMake(MAX(1, (int32_t)width), MAX(1, (int32_t)height));
    }
    return self;
}

- (void)dealloc {
    if (_instance != nullptr) {
        tlottie_drop(_instance);
        _instance = nullptr;
    }
}

- (void)renderFrameWithIndex:(int32_t)index
                        into:(uint8_t * _Nonnull)buffer
                       width:(int32_t)width
                      height:(int32_t)height
                 bytesPerRow:(int32_t)bytesPerRow {
    if (_instance == nullptr || width <= 0 || height <= 0) {
        return;
    }

    size_t pixelCount = (size_t)width * (size_t)height;
    size_t packedBytesPerRow = (size_t)width * 4;

    if ((size_t)bytesPerRow == packedBytesPerRow) {
        // Fast path: the destination is already tightly packed, so tlottie can
        // write straight into it.
        tlottie_render(_instance, (float)index, (uint32_t)width, (uint32_t)height,
                       (uint32_t *)buffer, pixelCount, 1);
        return;
    }

    // tlottie has no stride parameter and is packed all the way down, while
    // every call site here passes a 32- or 64-byte-aligned bytesPerRow from
    // DeviceGraphicsContextSettings. Render packed, then place the rows.
    if (_scratch.size() < pixelCount) {
        _scratch.resize(pixelCount);
    }
    tlottie_render(_instance, (float)index, (uint32_t)width, (uint32_t)height,
                   _scratch.data(), pixelCount, 1);

    for (int32_t y = 0; y < height; y++) {
        memcpy(buffer + (size_t)y * (size_t)bytesPerRow,
               _scratch.data() + (size_t)y * (size_t)width,
               packedBytesPerRow);
    }
}

@end
