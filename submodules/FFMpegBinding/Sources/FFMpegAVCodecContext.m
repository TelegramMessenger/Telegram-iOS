#import <FFMpegBinding/FFMpegAVCodecContext.h>

#import <FFMpegBinding/FFMpegAVFrame.h>
#import <FFMpegBinding/FFMpegAVCodec.h>

#import "libavcodec/avcodec.h"

@interface FFMpegAVCodecContext () {
    FFMpegAVCodec *_codec;
    AVCodecContext *_impl;
}

@end

@implementation FFMpegAVCodecContext

- (instancetype)initWithCodec:(FFMpegAVCodec *)codec {
    self = [super init];
    if (self != nil) {
        _codec = codec;
        _impl = avcodec_alloc_context3((AVCodec *)[codec impl]);
    }
    return self;
}

- (void)dealloc {
    if (_impl) {
        avcodec_free_context(&_impl);
    }
}

- (void *)impl {
    return _impl;
}

- (int32_t)channels {
    return (int32_t)_impl->channels;
}

- (int32_t)sampleRate {
    return (int32_t)_impl->sample_rate;
}

- (FFMpegAVSampleFormat)sampleFormat {
    return (FFMpegAVSampleFormat)_impl->sample_fmt;
}

- (bool)open {
    int result = avcodec_open2(_impl, (AVCodec *)[_codec impl], nil);
    return result >= 0;
}

- (bool)sendEnd {
    int status = avcodec_send_packet(_impl, nil);
    return status == 0;
}

- (FFMpegAVCodecContextReceiveResult)receiveIntoFrame:(FFMpegAVFrame *)frame {
    int status = avcodec_receive_frame(_impl, (AVFrame *)[frame impl]);
    if (status == 0) {
        return FFMpegAVCodecContextReceiveResultSuccess;
    } else if (status == -35) {
        return FFMpegAVCodecContextReceiveResultNotEnoughData;
    } else {
        return FFMpegAVCodecContextReceiveResultError;
    }
}

- (void)flushBuffers {
    avcodec_flush_buffers(_impl);
}

@end
