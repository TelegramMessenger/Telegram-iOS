//
//  SVGEllipseElement.m
//  SVGKit
//
//  Copyright Matt Rajca 2010-2011. All rights reserved.
//

#import "SVGEllipseElement.h"

#import "SVGElement_ForParser.h" // to resolve Xcode circular dependencies; in long term, parsing SHOULD NOT HAPPEN inside any class whose name starts "SVG" (because those are reserved classes for the SVG Spec)

#import "SVGHelperUtilities.h"

@interface SVGEllipseElement()
@property (nonatomic, readwrite) CGFloat cx;
@property (nonatomic, readwrite) CGFloat cy;
@property (nonatomic, readwrite) CGFloat rx;
@property (nonatomic, readwrite) CGFloat ry;
@end

@implementation SVGEllipseElement

@synthesize cx = _cx;
@synthesize cy = _cy;
@synthesize rx = _rx;
@synthesize ry = _ry;

- (void)postProcessAttributesAddingErrorsTo:(SVGKParseResult *)parseResult {
	[super postProcessAttributesAddingErrorsTo:parseResult];
	
	SVGRect r = parseResult.rootOfSVGTree.viewport;
	
	if( [[self getAttribute:@"cx"] length] > 0 )
	{
		self.cx = [[SVGLength svgLengthFromNSString:[self getAttribute:@"cx"] ]
		 			pixelsValueWithDimension:r.width];
	}
	if( [[self getAttribute:@"cy"] length] > 0 )
	{
		self.cy = [[SVGLength svgLengthFromNSString:[self getAttribute:@"cy"] ]
				   pixelsValueWithDimension:r.height];
	}
	if( [[self getAttribute:@"rx"] length] > 0 )
	{
		self.rx  = [[SVGLength svgLengthFromNSString:[self getAttribute:@"rx"] ]
					pixelsValueWithDimension:r.width];
	}
	if( [[self getAttribute:@"ry"] length] > 0 )
	{
		self.ry =  [[SVGLength svgLengthFromNSString:[self getAttribute:@"ry"] ]
					 pixelsValueWithDimension:r.height];
	}
	if( [[self getAttribute:@"r"] length] > 0 ) { // circle
		
		self.ry = self.rx = [[SVGLength svgLengthFromNSString:[self getAttribute:@"r"] ]
							 pixelsValueWithDimension:hypot(r.width, r.height)/M_SQRT2];
	}
    
    CGMutablePathRef path = CGPathCreateMutable();
	CGPathAddEllipseInRect(path, NULL, CGRectMake(self.cx - self.rx, self.cy - self.ry, self.rx * 2, self.ry * 2));
	self.pathForShapeInRelativeCoords = path;
    CGPathRelease(path);
}

@end
