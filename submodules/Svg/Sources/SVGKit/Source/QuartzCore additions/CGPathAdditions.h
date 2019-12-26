//
//  CGPathAdditions.h
//  SVGPad
//
//  Copyright Matt Rajca 2011. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>

/*! From original SVGKit, but it seems to be "the opposite of translation" */
CGPathRef CGPathCreateByOffsettingPath (CGPathRef aPath, CGFloat x, CGFloat y);

/*! New SVGKit: carefully named method that does what it claims to: it translates a path by the specified amount */
CGPathRef CGPathCreateByTranslatingPath (CGPathRef aPath, CGFloat x, CGFloat y);
