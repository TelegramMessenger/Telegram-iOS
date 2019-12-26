#import "BaseClassForAllSVGBasicShapes.h"
#import "BaseClassForAllSVGBasicShapes_ForSubclasses.h"

#import "CGPathAdditions.h"
#import "SVGDefsElement.h"
#import "SVGKPattern.h"
#import "CAShapeLayerWithHitTest.h"

#import "SVGElement_ForParser.h" // to resolve Xcode circular dependencies; in long term, parsing SHOULD NOT HAPPEN inside any class whose name starts "SVG" (because those are reserved classes for the SVG Spec)

#import "SVGHelperUtilities.h"

@implementation BaseClassForAllSVGBasicShapes

@synthesize pathForShapeInRelativeCoords = _pathForShapeInRelativeCoords;

@synthesize transform; // each SVGElement subclass that conforms to protocol "SVGTransformable" has to re-synthesize this to work around bugs in Apple's Objective-C 2.0 design that don't allow @properties to be extended by categories / protocols

- (id)init
{
    self = [super init];
    if (self) {
        self.pathForShapeInRelativeCoords = NULL;
    }
    return self;
}


- (void)dealloc {
	CGPathRelease(_pathForShapeInRelativeCoords);
    
}

-(void)setPathForShapeInRelativeCoords:(CGPathRef)pathForShapeInRelativeCoords
{
	if( pathForShapeInRelativeCoords == _pathForShapeInRelativeCoords )
		return;
	
	CGPathRelease( _pathForShapeInRelativeCoords ); // Apple says NULL is fine as argument
	_pathForShapeInRelativeCoords = pathForShapeInRelativeCoords;
	CGPathRetain( _pathForShapeInRelativeCoords );
}

- (CALayer *) newLayer
{
	NSAssert(self.pathForShapeInRelativeCoords != NULL, @"Requested a CALayer for SVG shape that never initialized its own .pathForShapeInRelativeCoords property. Shape class = %@. Shape instance = %@", [self class], self );
	
	return [SVGHelperUtilities newCALayerForPathBasedSVGElement:self withPath:self.pathForShapeInRelativeCoords];
}

- (void)layoutLayer:(CALayer *)layer { }

@end
