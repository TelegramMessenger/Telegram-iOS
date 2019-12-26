/*
// https://www.w3.org/TR/SVG/pservers.html#InterfaceSVGLinearGradientElement
 
 interface SVGLinearGradientElement : SVGGradientElement {
 [SameObject] readonly attribute SVGAnimatedLength x1;
 [SameObject] readonly attribute SVGAnimatedLength y1;
 [SameObject] readonly attribute SVGAnimatedLength x2;
 [SameObject] readonly attribute SVGAnimatedLength y2;
 };
 
*/

#import "SVGGradientElement.h"

@interface SVGLinearGradientElement : SVGGradientElement

@property (nonatomic, readonly) SVGLength *x1;
@property (nonatomic, readonly) SVGLength *y1;
@property (nonatomic, readonly) SVGLength *x2;
@property (nonatomic, readonly) SVGLength *y2;

@end
