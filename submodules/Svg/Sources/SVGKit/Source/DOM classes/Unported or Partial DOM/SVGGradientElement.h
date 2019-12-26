/*
//
 http://www.w3.org/TR/SVG/pservers.html#InterfaceSVGGradientElement
 
 interface SVGGradientElement : SVGElement,

 SVGURIReference,
 SVGExternalResourcesRequired,
 SVGStylable,
 SVGUnitTypes {
 
 // Spread Method Types
 const unsigned short SVG_SPREADMETHOD_UNKNOWN = 0;
 const unsigned short SVG_SPREADMETHOD_PAD = 1;
 const unsigned short SVG_SPREADMETHOD_REFLECT = 2;
 const unsigned short SVG_SPREADMETHOD_REPEAT = 3;
 
 readonly attribute SVGAnimatedEnumeration gradientUnits;
 readonly attribute SVGAnimatedTransformList gradientTransform;
 readonly attribute SVGAnimatedEnumeration spreadMethod;
 
 */

#import "SVGElement.h"
#import "SVGRect.h"
#import "SVGGradientStop.h"
#import "SVGTransformable.h"
#import "SVGPreserveAspectRatio.h"
#import "SVGUnitTypes.h"

typedef NS_ENUM(NSUInteger, SVGSpreadMethod) {
    SVGSpreadMethodUnkown = 0,
    SVGSpreadMethodPad = 1,
    SVGSpreadMethodReflect = 2,
    SVGSpreadMethodRepeat = 3
};

@class SVGGradientLayer;
@interface SVGGradientElement : SVGElement <SVGTransformable> /* NB: does NOT implemente "SVGLayeredElement" because spec says that these specifically NEVER appear in the output */

@property (readonly, strong) NSArray *stops; /* FIXME: not in SVG Spec */
@property (readonly, strong) NSArray *locations; /* FIXME: not in SVG Spec */
@property (readonly, strong) NSArray *colors; /* FIXME: not in SVG Spec */

@property (readonly, assign) SVG_UNIT_TYPE gradientUnits;
@property (readonly, assign) SVGSpreadMethod spreadMethod; /* FIXME: currently only support `pad`. other methods are not supported */


-(void)addStop:(SVGGradientStop *)gradientStop; /* FIXME: not in SVG Spec */

-(NSString*) getAttributeInheritedIfNil:(NSString*)attrName;
-(SVGGradientLayer *)newGradientLayerForObjectRect:(CGRect)objectRect
                                      viewportRect:(SVGRect)viewportRect
                                         transform:(CGAffineTransform)transform;

- (void)synthesizeProperties; // resolve any xlink:hrefs to other gradients
@end
