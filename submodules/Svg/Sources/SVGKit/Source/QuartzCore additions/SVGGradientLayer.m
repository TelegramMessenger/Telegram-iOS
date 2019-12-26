//
//  SVGGradientLayer.m
//  SVGKit-iOS
//
//  Created by zhen ling tsai on 19/7/13.
//  Copyright (c) 2013 na. All rights reserved.
//

#import "SVGGradientLayer.h"
#import "SVGRadialGradientElement.h"
#import "SVGLinearGradientElement.h"
#import "CALayerWithClipRender.h"

@implementation SVGGradientLayer

- (void)renderInContext:(CGContextRef)ctx {
    if (!self.gradientElement) {
        [super renderInContext:ctx];
        return;
    }
    if ([self.gradientElement isKindOfClass:[SVGRadialGradientElement class]]) {
        [self renderRadialGradientInContext:ctx];
    } else if ([self.gradientElement isKindOfClass:[SVGLinearGradientElement class]]) {
        [self renderLinearGradientInContext:ctx];
    }
}

- (CGGradientRef)createCGGradient {
    SVGGradientElement *gradientElement = self.gradientElement;
    if ([gradientElement isKindOfClass:[SVGRadialGradientElement class]]) {
        SVGLength *svgR = ((SVGRadialGradientElement *)gradientElement).r;
        if (svgR.value <= 0) {
            return nil;
        }
    }
    // CGGradient
    NSArray *colors = gradientElement.colors;
    NSArray *locations = gradientElement.locations;
    if (colors.count == 0) {
        SVGKitLogWarn(@"[%@] colors count is zero", [self class]);
        return NULL;
    }
    if (colors.count != locations.count) {
        SVGKitLogWarn(@"[%@] colors count : %lu != locations count : %lu", [self class], (unsigned long)colors.count, (unsigned long)locations.count);
        return NULL;
    }
    CGFloat locations_array[locations.count];
    CGColorSpaceRef colorSpace = NULL;
    for (int i = 0; i < locations.count; i++) {
        CGFloat location = [[locations objectAtIndex:i] doubleValue];
        CGColorRef colorRef = (__bridge CGColorRef)[colors objectAtIndex:i];
        locations_array[i] = location;
        if (!colorSpace) {
            colorSpace = CGColorGetColorSpace(colorRef);
        }
    }
    
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations_array);
    CGColorSpaceRelease(colorSpace);
    
    return gradient;
}

- (void)renderLinearGradientInContext:(CGContextRef)ctx {
    SVGLinearGradientElement *gradientElement = (SVGLinearGradientElement *)self.gradientElement;
    BOOL inUserSpace = gradientElement.gradientUnits == SVG_UNIT_TYPE_USERSPACEONUSE;
    CGRect objectRect = self.objectRect;
    CGRect rectForRelativeUnits = inUserSpace ? CGRectFromSVGRect( self.viewportRect ) : objectRect;
    
    CGFloat width = CGRectGetWidth(rectForRelativeUnits);
    CGFloat height = CGRectGetHeight(rectForRelativeUnits);
    CGFloat x1 = [gradientElement.x1 pixelsValueWithGradientDimension:width];
    CGFloat y1 = [gradientElement.y1 pixelsValueWithGradientDimension:height];
    CGFloat x2 = [gradientElement.x2 pixelsValueWithGradientDimension:width];
    CGFloat y2 = [gradientElement.y2 pixelsValueWithGradientDimension:height];
    CGPoint gradientStartPoint = CGPointMake(x1, y1);
    CGPoint gradientEndPoint = CGPointMake(x2, y2);
    
    // transforms
    CGAffineTransform selfTransform = gradientElement.transform;
    CGAffineTransform trans = CGAffineTransformMakeTranslation(-CGRectGetMinX(objectRect),
                                                               -CGRectGetMinY(objectRect));
    CGAffineTransform absoluteTransform = CGAffineTransformConcat(self.absoluteTransform,trans);
    
    // CGGradient
    CGGradientRef gradient = [self createCGGradient];
    
    CGContextSaveGState(ctx);
    {
        // clip the mask
        if (self.mask)
        {
            [CALayerWithClipRender maskLayer:self inContext:ctx];
        }
        if(inUserSpace == YES) {
#pragma mark User Space On Use
            // transform absolute - due to user space
            CGContextConcatCTM(ctx, absoluteTransform);
        } else {
#pragma mark Object Bounding Box
        }
        
        // set the opacity
        CGContextSetAlpha(ctx, self.opacity);
        
        // transform the context
        CGContextConcatCTM(ctx, selfTransform);
        
        // draw the gradient
        CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation|
        kCGGradientDrawsAfterEndLocation;
        
        CGContextDrawLinearGradient(ctx, gradient, gradientStartPoint,
                                    gradientEndPoint, options);
        CGGradientRelease(gradient);
    };
    CGContextRestoreGState(ctx);
}

-(void)renderRadialGradientInContext:(CGContextRef)ctx {
    SVGRadialGradientElement *gradientElement = (SVGRadialGradientElement *)self.gradientElement;
    BOOL inUserSpace = gradientElement.gradientUnits == SVG_UNIT_TYPE_USERSPACEONUSE;
    CGRect objectRect = self.objectRect;
    CGRect rectForRelativeUnits = inUserSpace ? CGRectFromSVGRect( self.viewportRect ) : objectRect;
    
    CGFloat width = CGRectGetWidth(rectForRelativeUnits);
    CGFloat height = CGRectGetHeight(rectForRelativeUnits);
    CGFloat cx = [gradientElement.cx pixelsValueWithGradientDimension:width];
    CGFloat cy = [gradientElement.cy pixelsValueWithGradientDimension:height];
    CGPoint startPoint = CGPointMake(cx, cy);
    
    CGFloat val = MIN(width, height);
    CGFloat radius = [gradientElement.r pixelsValueWithGradientDimension:val];
    CGFloat focalRadius = [gradientElement.fr pixelsValueWithGradientDimension:val];
    
    CGFloat fx = [gradientElement.fx pixelsValueWithGradientDimension:width];
    CGFloat fy = [gradientElement.fy pixelsValueWithGradientDimension:height];
    
    CGPoint gradientEndPoint = CGPointMake(fx, fy);
    CGPoint gradientStartPoint = startPoint;
    
    // transforms
    CGAffineTransform selfTransform = gradientElement.transform;
    CGAffineTransform trans = CGAffineTransformMakeTranslation(-CGRectGetMinX(objectRect),
                                                               -CGRectGetMinY(objectRect));
    CGAffineTransform absoluteTransform = CGAffineTransformConcat(self.absoluteTransform,trans);
    
    // CGGradient
    CGGradientRef gradient = [self createCGGradient];
    
    CGContextSaveGState(ctx);
    {
        // clip the mask
        if (self.mask)
        {
            [CALayerWithClipRender maskLayer:self inContext:ctx];
        }
#pragma mark User Space On Use
        if(inUserSpace == YES) {
            // work out the new radius
            CGFloat rad = 2 * radius;
            CGRect rect = CGRectMake(startPoint.x, startPoint.y, rad, rad);
            rect = CGRectApplyAffineTransform(rect, selfTransform);
            rect = CGRectApplyAffineTransform(rect, absoluteTransform);
            radius = CGRectGetHeight(rect)/2.f;
            
            // transform absolute - due to user space
            CGContextConcatCTM(ctx, absoluteTransform);
        } else {
#pragma mark Object Bounding Box
            // SVG spec: transform if width or height is not equal
            if(CGRectGetWidth(objectRect) != CGRectGetHeight(objectRect)) {
                CGAffineTransform tr = CGAffineTransformMakeTranslation(gradientStartPoint.x,
                                                                        gradientStartPoint.y);
                if(CGRectGetWidth(objectRect) > CGRectGetHeight(objectRect)) {
                    tr = CGAffineTransformScale(tr, CGRectGetWidth(objectRect)/CGRectGetHeight(objectRect), 1);
                } else {
                    tr = CGAffineTransformScale(tr, 1.f, CGRectGetHeight(objectRect)/CGRectGetWidth(objectRect));
                }
                tr = CGAffineTransformTranslate(tr, -gradientStartPoint.x, -gradientStartPoint.y);
                selfTransform = CGAffineTransformConcat(tr, selfTransform);
            }
        }
        
        // set the opacity
        CGContextSetAlpha(ctx, self.opacity);
        
#pragma mark Default drawing
        // transform the context
        CGContextConcatCTM(ctx, selfTransform);
        
        if (gradient) {
            // draw the gradient
            CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation|
            kCGGradientDrawsAfterEndLocation;
            CGContextDrawRadialGradient(ctx, gradient,
                                        gradientEndPoint, focalRadius, gradientStartPoint,
                                        radius, options);
            CGGradientRelease(gradient);
        } else {
            // draw the background
            CGColorRef backgroundColor = self.backgroundColor;
            CGContextSetFillColorWithColor(ctx, backgroundColor);
            CGContextFillRect(ctx, CGRectMake(0, 0, CGRectGetWidth(objectRect), CGRectGetHeight(objectRect)));
        }
    };
    CGContextRestoreGState(ctx);
}

@end
