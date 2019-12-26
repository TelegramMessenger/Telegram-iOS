//
//  CALayerWithClipRender.m
//  SVGKit-iOS
//
//  Created by David Gileadi on 8/14/14.
//  Copyright (c) 2014 na. All rights reserved.
//

#import "CALayerWithClipRender.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CALayer (ContentsTransform)

@property CGAffineTransform contentsTransform;

@end

@implementation CALayerWithClipRender

- (void)renderInContext:(CGContextRef)ctx {
    CALayer *mask = nil;
    if( self.mask != nil ) {
        [CALayerWithClipRender maskLayer:self inContext:ctx];
        
        mask = self.mask;
        self.mask = nil;
    }
    
    // We use the flipped coordinate system on macOS, to match the behavior of iOS. However, the `contents` (which is a CGImageRef) bitmap provided by image element is not been flipped as we want. The `renderInContext:` which used by `SVGKFastImageView` will not correct this coordinate system issue, only `SVGKLayeredImageView` do. So we use the `contentsTransform` to manually fix it.
#if SVGKIT_MAC
    // If already flipped, which should be handled by Core Animation itself, ignore
    if (self.contentsAreFlipped) {
        [super renderInContext:ctx];
    } else {
        self.contentsTransform = CGAffineTransformMake(1, 0, 0, -1, 0, self.bounds.size.height);
        [super renderInContext:ctx];
        self.contentsTransform = CGAffineTransformIdentity;
    }
#else
    [super renderInContext:ctx];
#endif
    
    if( mask != nil ) {
        self.mask = mask;
    }
}

+ (void)maskLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    // if all that's masking is a single path, just clip to it
    if( layer.mask.sublayers.count == 1 && [[layer.mask.sublayers objectAtIndex:0] isKindOfClass:[CAShapeLayer class]] ) {
        CGPathRef maskPath = ((CAShapeLayer *) [layer.mask.sublayers objectAtIndex:0]).path;
        // we have to undo the offset from SVGClipPathLayer.layoutLayer
        CGAffineTransform offset = CGAffineTransformMakeTranslation(layer.mask.frame.origin.x, layer.mask.frame.origin.y);
        CGPathRef translatedPath = CGPathCreateCopyByTransformingPath(maskPath, &offset);
        CGContextAddPath(ctx, translatedPath);
        CGPathRelease(translatedPath);
        CGContextClip(ctx);
    } else {
        // otherwise, create an offscreen bitmap at screen resolution,
        CGFloat scale = MAX(layer.contentsScale, layer.mask.contentsScale);
#if SVGKIT_MAC
        scale = MAX(scale, [[NSScreen mainScreen] backingScaleFactor]);
#else
        scale = MAX(scale, [[UIScreen mainScreen] scale]);
#endif
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
        CGContextRef offscreenContext = CGBitmapContextCreate(NULL,
                                                              layer.bounds.size.width * scale,
                                                              layer.bounds.size.height * scale,
                                                              8, 0,
                                                              colorSpace,
                                                              (CGBitmapInfo)kCGImageAlphaOnly);
        CGContextScaleCTM(offscreenContext, scale, scale);
        
        // render the mask to it, undoing the offset from SVGClipPathLayer.layoutLayer
        CGPoint offset = layer.mask.frame.origin;
        for (CALayer *child in layer.mask.sublayers)
            child.frame = CGRectOffset(child.frame, offset.x, offset.y);
        [layer.mask renderInContext:offscreenContext];
        for (CALayer *child in layer.mask.sublayers)
            child.frame = CGRectOffset(child.frame, -offset.x, -offset.y);
        
        // get an image from it,
        CGImageRef maskImage = CGBitmapContextCreateImage(offscreenContext);
        CGContextRelease(offscreenContext);
        CGColorSpaceRelease(colorSpace);
        
        // and mask with that
        CGContextClipToMask(ctx, layer.bounds, maskImage);
        
        CFRelease(maskImage);
    }
}

@end
