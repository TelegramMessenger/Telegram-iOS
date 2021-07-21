#import <FFMpegBinding/FFMpegSWResample.h>

#import <FFMpegBinding/FFMpegAVFrame.h>

#import "libavcodec/avcodec.h"
#import "libswresample/swresample.h"

@interface FFMpegSWResample () {
    int _sourceSampleRate;
    FFMpegAVSampleFormat _sourceSampleFormat;
    int _destinationChannelCount;
    int _destinationSampleRate;
    FFMpegAVSampleFormat _destinationSampleFormat;

    int _currentSourceChannelCount;

    SwrContext *_context;
    NSUInteger _ratio;
    void *_buffer;
    int _bufferSize;
}

@end

@implementation FFMpegSWResample

- (instancetype)initWithSourceChannelCount:(NSInteger)sourceChannelCount sourceSampleRate:(NSInteger)sourceSampleRate sourceSampleFormat:(enum FFMpegAVSampleFormat)sourceSampleFormat destinationChannelCount:(NSInteger)destinationChannelCount destinationSampleRate:(NSInteger)destinationSampleRate destinationSampleFormat:(enum FFMpegAVSampleFormat)destinationSampleFormat {
    self = [super init];
    if (self != nil) {
        _sourceSampleRate = (int)sourceSampleRate;
        _sourceSampleFormat = sourceSampleFormat;
        _destinationChannelCount = (int)destinationChannelCount;
        _destinationSampleRate = (int)destinationSampleRate;
        _destinationSampleFormat = destinationSampleFormat;

        _currentSourceChannelCount = -1;
    }
    return self;
}

- (void)dealloc {
    if (_context) {
        swr_free(&_context);
    }
    if (_buffer) {
        free(_buffer);
    }
}

- (void)resetContextForChannelCount:(int)channelCount {
    if (_context) {
        swr_free(&_context);
        _context = NULL;
    }

    _context = swr_alloc_set_opts(NULL,
                                  av_get_default_channel_layout((int)_destinationChannelCount),
                                  (enum AVSampleFormat)_destinationSampleFormat,
                                  (int)_destinationSampleRate,
                                  av_get_default_channel_layout(channelCount),
                                  (enum AVSampleFormat)_sourceSampleFormat,
                                  (int)_sourceSampleRate,
                                  0,
                                  NULL);
    _currentSourceChannelCount = channelCount;
    _ratio = MAX(1, _destinationSampleRate / MAX(_sourceSampleRate, 1)) * MAX(1, _destinationChannelCount / channelCount) * 2;
    if (_context) {
        swr_init(_context);
    }
}

- (NSData * _Nullable)resample:(FFMpegAVFrame *)frame {
    AVFrame *frameImpl = (AVFrame *)[frame impl];

    int numChannels = frameImpl->channels;
    if (numChannels != _currentSourceChannelCount) {
        [self resetContextForChannelCount:numChannels];
    }

    if (!_context) {
        return nil;
    }

    int bufSize = av_samples_get_buffer_size(NULL,
                                             (int)_destinationChannelCount,
                                             frameImpl->nb_samples * (int)_ratio,
                                             (enum AVSampleFormat)_destinationSampleFormat,
                                             1);
    
    if (!_buffer || _bufferSize < bufSize) {
        _bufferSize = bufSize;
        _buffer = realloc(_buffer, _bufferSize);
    }
    
    Byte *outbuf[2] = { _buffer, 0 };
    
    int numFrames = swr_convert(_context,
                                outbuf,
                                frameImpl->nb_samples * (int)_ratio,
                                (const uint8_t **)frameImpl->data,
                                frameImpl->nb_samples);
    if (numFrames <= 0) {
        return nil;
    }
    
    return [[NSData alloc] initWithBytes:_buffer length:numFrames * _destinationChannelCount * 2];
}

@end
