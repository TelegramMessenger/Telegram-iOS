#import <FFMpegBinding/FFMpegAVCodec.h>

#import "libavcodec/avcodec.h"

@interface FFMpegAVCodec () {
    AVCodec const *_impl;
}

@end

@implementation FFMpegAVCodec

- (instancetype)initWithImpl:(AVCodec const *)impl {
    self = [super init];
    if (self != nil) {
        _impl = impl;
    }
    return self;
}

+ (FFMpegAVCodec * _Nullable)findForId:(int)codecId preferHardwareAccelerationCapable:(_Bool)preferHardwareAccelerationCapable {
    if (preferHardwareAccelerationCapable && codecId == AV_CODEC_ID_AV1) {
        void *codecIterationState = nil;
        while (true) {
            AVCodec const *codec = av_codec_iterate(&codecIterationState);
            if (!codec) {
                break;
            }
            if (!av_codec_is_decoder(codec)) {
                continue;
            }
            if (codec->id != codecId) {
                continue;
            }
            if (strncmp(codec->name, "av1", 2) == 0) {
                return [[FFMpegAVCodec alloc] initWithImpl:codec];
            }
        }
    } else if (preferHardwareAccelerationCapable && codecId == AV_CODEC_ID_H264) {
        void *codecIterationState = nil;
        while (true) {
            AVCodec const *codec = av_codec_iterate(&codecIterationState);
            if (!codec) {
                break;
            }
            if (!av_codec_is_decoder(codec)) {
                continue;
            }
            if (codec->id != codecId) {
                continue;
            }
            if (strncmp(codec->name, "h264", 2) == 0) {
                return [[FFMpegAVCodec alloc] initWithImpl:codec];
            }
        }
    } else if (preferHardwareAccelerationCapable && codecId == AV_CODEC_ID_HEVC) {
        void *codecIterationState = nil;
        while (true) {
            AVCodec const *codec = av_codec_iterate(&codecIterationState);
            if (!codec) {
                break;
            }
            if (!av_codec_is_decoder(codec)) {
                continue;
            }
            if (codec->id != codecId) {
                continue;
            }
            if (strncmp(codec->name, "hevc", 2) == 0) {
                return [[FFMpegAVCodec alloc] initWithImpl:codec];
            }
        }
    }
    
    AVCodec const *codec = avcodec_find_decoder(codecId);
    if (codec) {
        return [[FFMpegAVCodec alloc] initWithImpl:codec];
    } else {
        return nil;
    }
}

- (void *)impl {
    return (void *)_impl;
}

@end
