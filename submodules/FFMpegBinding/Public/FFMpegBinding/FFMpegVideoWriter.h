#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@class FFMpegAVFrame;

@interface FFMpegVideoWriter : NSObject

- (bool)setupWithOutputPath:(NSString *)outputPath width:(int)width height:(int)height bitrate:(int64_t)bitrate framerate:(int32_t)framerate;
- (bool)encodeFrame:(FFMpegAVFrame *)frame;
- (bool)finalizeVideo;

@end

NS_ASSUME_NONNULL_END
