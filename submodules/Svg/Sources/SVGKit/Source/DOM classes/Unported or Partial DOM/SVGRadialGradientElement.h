/*
 https://www.w3.org/TR/SVG/pservers.html#InterfaceSVGRadialGradientElement
 
 interface SVGRadialGradientElement : SVGGradientElement {
 [SameObject] readonly attribute SVGAnimatedLength cx;
 [SameObject] readonly attribute SVGAnimatedLength cy;
 [SameObject] readonly attribute SVGAnimatedLength r;
 [SameObject] readonly attribute SVGAnimatedLength fx;
 [SameObject] readonly attribute SVGAnimatedLength fy;
 [SameObject] readonly attribute SVGAnimatedLength fr;
 };
 */

#import "SVGGradientElement.h"

@interface SVGRadialGradientElement : SVGGradientElement

@property (nonatomic, readonly) SVGLength *cx;
@property (nonatomic, readonly) SVGLength *cy;
@property (nonatomic, readonly) SVGLength *r;
@property (nonatomic, readonly) SVGLength *fx;
@property (nonatomic, readonly) SVGLength *fy;
@property (nonatomic, readonly) SVGLength *fr;

@end
