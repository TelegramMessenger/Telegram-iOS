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
- (FFMpegAVCodecContextReceiveResult)receiveIntoFrame:(FFMpegAVFrame *)frame;
- (void)flushBuffers;

@end

NS_ASSUME_NONNULL_END
