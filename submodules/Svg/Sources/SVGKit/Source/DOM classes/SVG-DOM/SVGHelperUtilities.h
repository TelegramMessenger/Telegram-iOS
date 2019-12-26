/**
 To implement the official SVG Spec, some "extra" methods are needed that are SHARED between classes, but
 which in the SVG Spec the classes aren't subclass/superclass of each other - so that there's no way to
 implement it without copy/pasting the code.
 
 To improve maintainability, we put those methods here, and then each place we need them has a 1-line method
 that delegates to a method body in this class.
 */
#import <Foundation/Foundation.h>

#import <QuartzCore/QuartzCore.h>
#import "SVGElement.h"
#import "SVGTransformable.h"
#import "SVGFitToViewBox.h"

#define FORCE_RASTERIZE_LAYERS 0 // If True, all CALayers will be told to rasterize themselves. This MIGHT increase performance (or might not), but leads to blurriness whenever a layer is scaled / zoomed in
#define IMPROVE_PERFORMANCE_BY_WORKING_AROUND_APPLE_FRAME_ALIGNMENT_BUG 1 // NB: Apple's code for rendering ANY CALayer is extremely slow if the layer has non-integer co-ordinates for its "frame" or "bounds" property. This flag technically makes your SVG's render incorrect at sub-pixel level, but often increases performance of Apple's rendering by a factor of 2 or more!
@class SVGGradientLayer;
@interface SVGHelperUtilities : NSObject

/**
 According to the SVG Spec, there are two types of element that affect the on-screen size/shape/position/rotation/skew of shapes/images:
 
 1. Any ancestor that implements SVGTransformable
 2. Any "element that establishes a new viewport" - i.e. the <svg> tag and a few others
 
This method ONLY looks at current node to establish the above two things, to do a RELATIVE transform (relative to parent node)
 */
+(CGAffineTransform) transformRelativeIncludingViewportForTransformableOrViewportEstablishingElement:(SVGElement*) transformableOrSVGSVGElement;
/**
 According to the SVG Spec, there are two types of element that affect the on-screen size/shape/position/rotation/skew of shapes/images:
 
 1. Any ancestor that implements SVGTransformable
 2. Any "element that establishes a new viewport" - i.e. the <svg> tag and a few others
 
 This method recurses upwards to combine the above two things for everything in the tree, to establish an ABSOLUTE transform
 */
+(CGAffineTransform) transformAbsoluteIncludingViewportForTransformableOrViewportEstablishingElement:(SVGElement*) transformableOrSVGSVGElement;


/** Some things - e.g. setting layer's Opacity - have to be done for pretty much EVERY SVGElement; this method automatically looks
 at the incoming element, uses the protocols that element has (e.g. SVGStylable) to automatically adapt the layer.
 
 This allows each SVGElement subclass to create a custom CALayer as needed (e.g. CATextLayer for text elements), but share the setup
 code.
 
 If compiled with FORCE_RASTERIZE_LAYERS, also tells every layer to rasterize itself
 */
+(void) configureCALayer:(CALayer*) layer usingElement:(SVGElement*) nonStylableElement;

+(CALayer *) newCALayerForPathBasedSVGElement:(SVGElement*) svgElement withPath:(CGPathRef) path;
+ (SVGGradientLayer*)getGradientLayerWithId:(NSString*)gradId
                                 forElement:(SVGElement*)svgElement
                                   withRect:(CGRect)r
                                  transform:(CGAffineTransform)transform;

+(CGColorRef) parseFillForElement:(SVGElement *)svgElement;
+(CGColorRef) parseStrokeForElement:(SVGElement *)svgElement;
+(void) parsePreserveAspectRatioFor:(Element<SVGFitToViewBox>*) element;

@end
