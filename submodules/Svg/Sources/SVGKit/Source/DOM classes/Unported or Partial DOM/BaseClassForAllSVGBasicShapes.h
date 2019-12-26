/**
 This class is FOR IMPLEMENTATION ONLY, it is NOT part of the SVG Spec.
 
 All the SVG Basic Shapes are rendered in ObjectiveC using the same CGPath primitive - so this class provides
 a clean, OOP, way of implementing that.
 
 Sub-classes MUST write to the "pathForShapeInRelativeCoords" property, and this superclass will automatically generate
 the required CALayer on the fly, using that CGPath
 */

#import "SVGElement.h"
#import "ConverterSVGToCALayer.h"
#import "SVGUtils.h"
#import "SVGTransformable.h"

@class SVGGradientElement;
@class SVGKPattern;

@interface BaseClassForAllSVGBasicShapes : SVGElement < SVGStylable, SVGTransformable, ConverterSVGToCALayer >
{
	/* FIXME: are any of these private elements in the SVG spec? */
	NSString *_styleClass;
	CGRect _layerRect;
}

/** The actual path as parsed from the original file. THIS MIGHT NOT BE NORMALISED (TODO: perhaps an extra feature?) */
@property (nonatomic, readonly) CGPathRef pathForShapeInRelativeCoords;

@end
