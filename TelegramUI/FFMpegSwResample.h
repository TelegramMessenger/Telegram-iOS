#import <Foundation/Foundation.h>

#import "../third-party/FFMpeg-iOS/include/libavutil/avutil.h"
#import "../third-party/FFMpeg-iOS/include/libavutil/channel_layout.h"
#import "../third-party/FFMpeg-iOS/include/libswresample/swresample.h"

@interface FFMpegSwResample : NSObject

- (instancetype)initWithSourceChannelCount:(NSInteger)sourceChannelCount sourceSampleRate:(NSInteger)sourceSampleRate sourceSampleFormat:(enum AVSampleFormat)sourceSampleFormat destinationChannelCount:(NSInteger)destinationChannelCount destinationSampleRate:(NSInteger)destinationSampleRate destinationSampleFormat:(enum AVSampleFormat)destinationSampleFormat;
- (NSData *)resample:(AVFrame *)frame;

@end
