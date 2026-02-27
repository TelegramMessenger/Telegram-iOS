#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>

@class TGVideoCameraRendererBuffer;

@interface TGVideoCameraGLView : UIView

- (void)displayPixelBuffer:(TGVideoCameraRendererBuffer *)pixelBuffer;
- (void)flushPixelBufferCache;
- (void)reset;

@end
