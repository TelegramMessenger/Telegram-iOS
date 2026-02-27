#import <FFMpegBinding/FFMpegAVFrame.h>

#import "libavformat/avformat.h"

@interface FFMpegAVFrame () {
    AVFrame *_impl;
}

@end

@implementation FFMpegAVFrame

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _impl = av_frame_alloc();
    }
    return self;
}

-(instancetype)initWithPixelFormat:(FFMpegAVFramePixelFormat)pixelFormat width:(int32_t)width height:(int32_t)height {
    self = [super init];
    if (self != nil) {
        _impl = av_frame_alloc();
        switch (pixelFormat) {
            case FFMpegAVFramePixelFormatYUV:
                _impl->format = AV_PIX_FMT_YUV420P;
                break;
            case FFMpegAVFramePixelFormatYUVA:
                _impl->format = AV_PIX_FMT_YUVA420P;
                break;
        }
        _impl->width = width;
        _impl->height = height;
        
        av_frame_get_buffer(_impl, 0);
    }
    return self;
}

- (void)dealloc {
    if (_impl) {
        av_frame_free(&_impl);
    }
}

- (int32_t)width {
    return _impl->width;
}

- (int32_t)height {
    return _impl->height;
}

- (uint8_t **)data {
    return _impl->data;
}

- (int *)lineSize {
    return _impl->linesize;
}

- (int64_t)pts {
    return _impl->pts;
}

- (FFMpegAVFrameNativePixelFormat)nativePixelFormat {
    switch (_impl->format) {
        case AV_PIX_FMT_VIDEOTOOLBOX: {
            return FFMpegAVFrameNativePixelFormatVideoToolbox;
        }
        default: {
            return FFMpegAVFrameNativePixelFormatUnknown;
        }
    }
}

- (int64_t)duration {
#if LIBAVFORMAT_VERSION_MAJOR >= 59
    return _impl->duration;
#else
    return _impl->pkt_duration;
#endif
}

- (FFMpegAVFrameColorRange)colorRange {
    switch (_impl->color_range) {
        case AVCOL_RANGE_MPEG:
        case AVCOL_RANGE_UNSPECIFIED:
            return FFMpegAVFrameColorRangeRestricted;
        default:
            return FFMpegAVFrameColorRangeFull;
    }
}

- (void *)impl {
    return _impl;
}

- (FFMpegAVFramePixelFormat)pixelFormat {
    switch (_impl->format) {
        case AV_PIX_FMT_YUVA420P:
            return FFMpegAVFramePixelFormatYUVA;
        default:
            return FFMpegAVFramePixelFormatYUV;
    }
}

@end
