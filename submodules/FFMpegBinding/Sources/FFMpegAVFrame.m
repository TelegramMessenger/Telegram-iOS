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
