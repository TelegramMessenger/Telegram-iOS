//
//  CALayerWithClipRender.h
//  SVGKit-iOS
//
//  Created by David Gileadi on 8/14/14.
//  Copyright (c) 2014 na. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface CALayerWithClipRender : CALayer

+ (void)maskLayer:(CALayer *)layer inContext:(CGContextRef)ctx;

@end
