#import <Foundation/Foundation.h>

#import <FFMpegBinding/FFMpegAVSampleFormat.h>

NS_ASSUME_NONNULL_BEGIN

@class FFMpegAVFrame;

@interface FFMpegSWResample : NSObject

- (instancetype)initWithSourceChannelCount:(NSInteger)sourceChannelCount sourceSampleRate:(NSInteger)sourceSampleRate sourceSampleFormat:(enum FFMpegAVSampleFormat)sourceSampleFormat destinationChannelCount:(NSInteger)destinationChannelCount destinationSampleRate:(NSInteger)destinationSampleRate destinationSampleFormat:(enum FFMpegAVSampleFormat)destinationSampleFormat;
- (NSData * _Nullable)resample:(FFMpegAVFrame *)frame;

@end

NS_ASSUME_NONNULL_END
