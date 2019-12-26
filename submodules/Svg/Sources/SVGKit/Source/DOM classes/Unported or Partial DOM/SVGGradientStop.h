/*
 http://www.w3.org/TR/SVG/pservers.html#InterfaceSVGStopElement
 
 interface SVGStopElement : SVGElement,
 SVGStylable {
 readonly attribute SVGAnimatedNumber offset;
 */

#import "SVGElement.h"
#import "SVGUtils.h"


@interface SVGGradientStop : SVGElement

@property (nonatomic, readonly)CGFloat offset; /** FIXME: wrong units */
@property (nonatomic, readonly)CGFloat stopOpacity; /** FIXME: not in SVG Spec */
@property (nonatomic, readonly)SVGColor stopColor; /** FIXME: not in SVG Spec */

//@property (nonatomic, readonly)NSDictionary *style; //misc unaccounted for properties

@end
