#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class TGPaintPath;

@interface TGPaintRenderState : NSObject

- (void)reset;

@end

@interface TGPaintRender : NSObject

+ (CGRect)renderPath:(TGPaintPath *)path renderState:(TGPaintRenderState *)renderState;

@end
