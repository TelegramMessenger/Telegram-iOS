#import <Foundation/Foundation.h>

#import "libavutil/avutil.h"
#import "libavutil/channel_layout.h"
#import "libswresample/swresample.h"

@interface FFMpegSwResample : NSObject

- (instancetype)initWithSourceChannelCount:(NSInteger)sourceChannelCount sourceSampleRate:(NSInteger)sourceSampleRate sourceSampleFormat:(enum AVSampleFormat)sourceSampleFormat destinationChannelCount:(NSInteger)destinationChannelCount destinationSampleRate:(NSInteger)destinationSampleRate destinationSampleFormat:(enum AVSampleFormat)destinationSampleFormat;
- (NSData *)resample:(AVFrame *)frame;

@end
