#import "SVGTextPositioningElement.h"
#import "SVGTextPositioningElement_Mutable.h"

#import "SVGElement_ForParser.h" // because we do post-processing of the SVG x,y,dx,dy,rotate attributes

@implementation SVGTextPositioningElement

@synthesize x,y,dx,dy,rotate;


- (void)postProcessAttributesAddingErrorsTo:(SVGKParseResult *)parseResult
{
	[super postProcessAttributesAddingErrorsTo:parseResult];
	
	self.x = [self getAttributeAsSVGLength:@"x"];
	self.y = [self getAttributeAsSVGLength:@"y"];
	self.dx = [self getAttributeAsSVGLength:@"dx"];
	self.dy = [self getAttributeAsSVGLength:@"dy"];
	self.rotate = [self getAttributeAsSVGLength:@"rotate"];
}

@end
