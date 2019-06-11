#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>

@interface TGVideoCameraGLView : UIView

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)flushPixelBufferCache;
- (void)reset;

@end
