#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFMpegVideoWriter : NSObject

- (void)setupWithOutputPath:(NSString *)outputPath width:(int)width height:(int)height;
- (void)encodeFrame:(CVPixelBufferRef)pixelBuffer;
- (void)finalizeVideo;

@end

NS_ASSUME_NONNULL_END
