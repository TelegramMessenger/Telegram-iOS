#import <FFMpegBinding/FFMpegAVIOContext.h>

#import "libavformat/avformat.h"

@interface FFMpegAVIOContext () {
    AVIOContext *_impl;
}

@end

@implementation FFMpegAVIOContext

- (instancetype _Nullable)initWithBufferSize:(int32_t)bufferSize opaqueContext:(void * const)opaqueContext readPacket:(int (* _Nullable)(void * _Nullable opaque, uint8_t * _Nullable buf, int buf_size))readPacket writePacket:(int (* _Nullable)(void * _Nullable opaque, uint8_t * _Nullable buf, int buf_size))writePacket seek:(int64_t (*)(void * _Nullable opaque, int64_t offset, int whence))seek {
    self = [super init];
    if (self != nil) {
        void *avIoBuffer = av_malloc(bufferSize);
        _impl = avio_alloc_context(avIoBuffer, bufferSize, 0, opaqueContext, readPacket, writePacket, seek);
        _impl->direct = 1;
        if (_impl == nil) {
            av_free(avIoBuffer);
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    if (_impl != nil) {
        if (_impl->buffer != nil) {
            av_free(_impl->buffer);
        }
        av_free(_impl);
    }
}

- (void *)impl {
    return _impl;
}

@end
