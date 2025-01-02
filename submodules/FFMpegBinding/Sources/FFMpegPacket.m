#import <FFMpegBinding/FFMpegPacket.h>

#import <FFMpegBinding/FFMpegAVCodecContext.h>

#import "libavcodec/avcodec.h"
#import "libavformat/avformat.h"

@interface FFMpegPacket () {
    AVPacket *_impl;
}

@end

@implementation FFMpegPacket

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _impl = av_packet_alloc();
    }
    return self;
}

- (void)dealloc {
    av_packet_free(&_impl);
}

- (void *)impl {
    return _impl;
}

- (int64_t)pts {
    if (_impl->pts == 0x8000000000000000) {
        return _impl->dts;
    } else {
        return _impl->pts;
    }
}

- (int64_t)dts {
    return _impl->dts;
}

- (int64_t)duration {
    return _impl->duration;
}

- (int32_t)streamIndex {
    return (int32_t)_impl->stream_index;
}

- (int32_t)size {
    return (int32_t)_impl->size;
}

- (bool)isKeyframe {
    return (_impl->flags & AV_PKT_FLAG_KEY) != 0;
}

- (uint8_t *)data {
    return _impl->data;
}

- (int32_t)sendToDecoder:(FFMpegAVCodecContext *)codecContext {
    return avcodec_send_packet((AVCodecContext *)[codecContext impl], _impl);
}

@end
