#import <Foundation/Foundation.h>

#import <FFMpegBinding/FFMpegAVSampleFormat.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, FFMpegAVCodecContextReceiveResult)
{
    FFMpegAVCodecContextReceiveResultError,
    FFMpegAVCodecContextReceiveResultNotEnoughData,
    FFMpegAVCodecContextReceiveResultSuccess,
};

@class FFMpegAVCodec;
@class FFMpegAVFrame;

@interface FFMpegAVCodecContext : NSObject

- (instancetype)initWithCodec:(FFMpegAVCodec *)codec;

- (void *)impl;
- (int32_t)channels;
- (int32_t)sampleRate;
- (FFMpegAVSampleFormat)sampleFormat;

- (bool)open;
- (bool)sendEnd;
- (void)setupHardwareAccelerationIfPossible;
// Sets `skip_loop_filter = AVDISCARD_ALL`, disabling H.264/HEVC in-loop deblocking.
// Deblocked frames are also prediction references, so this drifts from the encoder's
// reconstruction until the next IDR, on top of the visible blocking. Only appropriate
// for small, short-looping thumbnails. Must be called before `open`.
- (void)setSkipLoopFilterToAll;
- (FFMpegAVCodecContextReceiveResult)receiveIntoFrame:(FFMpegAVFrame *)frame;
- (void)flushBuffers;

@end

NS_ASSUME_NONNULL_END
