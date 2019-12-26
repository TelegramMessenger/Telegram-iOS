//
//  CAShapeLayerWithClipRender.m
//  SVGKit-iOS
//
//  Created by David Gileadi on 8/14/14.
//  Copyright (c) 2014 na. All rights reserved.
//

#import "CAShapeLayerWithClipRender.h"
#import "CALayerWithClipRender.h"

@implementation CAShapeLayerWithClipRender

- (void)renderInContext:(CGContextRef)ctx {
	if (CGRectIsEmpty(self.bounds)) return;

    CALayer *mask = nil;
    if( self.mask != nil ) {
        [CALayerWithClipRender maskLayer:self inContext:ctx];
        
        mask = self.mask;
        self.mask = nil;
    }
    
    [super renderInContext:ctx];
    
    if( mask != nil ) {
        self.mask = mask;
    }
}

@end
