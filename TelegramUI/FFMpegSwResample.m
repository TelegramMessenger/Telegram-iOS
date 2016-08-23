#import "FFMpegSwResample.h"

@interface FFMpegSwResample () {
    SwrContext *_context;
    NSUInteger _ratio;
    NSInteger _destinationChannelCount;
    enum AVSampleFormat _destinationSampleFormat;
    void *_buffer;
    int _bufferSize;
}

@end

@implementation FFMpegSwResample

- (instancetype)initWithSourceChannelCount:(NSInteger)sourceChannelCount sourceSampleRate:(NSInteger)sourceSampleRate sourceSampleFormat:(enum AVSampleFormat)sourceSampleFormat destinationChannelCount:(NSInteger)destinationChannelCount destinationSampleRate:(NSInteger)destinationSampleRate destinationSampleFormat:(enum AVSampleFormat)destinationSampleFormat {
    self = [super init];
    if (self != nil) {
        _destinationChannelCount = destinationChannelCount;
        _destinationSampleFormat = destinationSampleFormat;
        _context = swr_alloc_set_opts(NULL,
                                      av_get_default_channel_layout((int)destinationChannelCount),
                                      destinationSampleFormat,
                                      (int)destinationSampleRate,
                                      av_get_default_channel_layout((int)sourceChannelCount),
                                      sourceSampleFormat,
                                      (int)sourceSampleRate,
                                      0,
                                      NULL);
        _ratio = MAX(1, destinationSampleRate / sourceSampleRate) * MAX(1, destinationChannelCount / sourceChannelCount) * 2;
        swr_init(_context);
    }
    return self;
}

- (void)dealloc {
    swr_free(&_context);
    if (_buffer) {
        free(_buffer);
    }
}

- (NSData *)resample:(AVFrame *)frame {
    int bufSize = av_samples_get_buffer_size(NULL,
                                             (int)_destinationChannelCount,
                                             frame->nb_samples * (int)_ratio,
                                             _destinationSampleFormat,
                                             1);
    
    if (!_buffer || _bufferSize < bufSize) {
        _bufferSize = bufSize;
        _buffer = realloc(_buffer, _bufferSize);
    }
    
    Byte *outbuf[2] = { _buffer, 0 };
    
    int numFrames = swr_convert(_context,
                                outbuf,
                                frame->nb_samples * (int)_ratio,
                                (const uint8_t **)frame->data,
                                frame->nb_samples);
    if (numFrames <= 0) {
        return nil;
    }
    
    return [[NSData alloc] initWithBytes:_buffer length:numFrames * _destinationChannelCount * 2];
}

@end
