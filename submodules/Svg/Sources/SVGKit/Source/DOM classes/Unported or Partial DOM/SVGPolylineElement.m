#import "SVGPolylineElement.h"

#import "SVGUtils.h"

#import "SVGElement_ForParser.h" // to resolve Xcode circular dependencies; in long term, parsing SHOULD NOT HAPPEN inside any class whose name starts "SVG" (because those are reserved classes for the SVG Spec)


@implementation SVGPolylineElement

- (void)postProcessAttributesAddingErrorsTo:(SVGKParseResult *)parseResult {
	[super postProcessAttributesAddingErrorsTo:parseResult];
	
	if( [[self getAttribute:@"points"] length] > 0 )
	{
		CGMutablePathRef path = createPathFromPointsInString([[self getAttribute:@"points"] UTF8String], NO);
		
		self.pathForShapeInRelativeCoords = path;
		CGPathRelease(path);
	}
}

@end
