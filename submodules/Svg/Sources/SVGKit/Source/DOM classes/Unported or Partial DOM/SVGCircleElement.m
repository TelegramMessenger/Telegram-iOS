//
//  SVGCircleElement.m
//  SVGKit
//
//  Copyright Matt Rajca 2010-2011. All rights reserved.
//

#import "SVGCircleElement.h"

@implementation SVGCircleElement

@dynamic r;

- (CGFloat)r {
	if (self.rx != self.ry) {
		SVGKitLogVerbose(@"Undefined radius of circle");
		return 0.0f;
	}
	
	return self.rx;
}

@end
