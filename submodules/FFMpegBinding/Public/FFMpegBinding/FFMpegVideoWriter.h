#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFMpegVideoWriter : NSObject

- (bool)setupWithOutputPath:(NSString *)outputPath width:(int)width height:(int)height;
- (bool)encodeFrame:(CVPixelBufferRef)pixelBuffer;
- (bool)finalizeVideo;

@end

NS_ASSUME_NONNULL_END
