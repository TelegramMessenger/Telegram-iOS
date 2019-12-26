/**
 http://www.w3.org/TR/2011/REC-SVG11-20110816/text.html#InterfaceSVGTextPositioningElement
 
 interface SVGTextPositioningElement : SVGTextContentElement {
 readonly attribute SVGAnimatedLengthList x;
 readonly attribute SVGAnimatedLengthList y;
 readonly attribute SVGAnimatedLengthList dx;
 readonly attribute SVGAnimatedLengthList dy;
 readonly attribute SVGAnimatedNumberList rotate;
 */

#import "SVGTextContentElement.h"
#import "SVGLength.h"

@interface SVGTextPositioningElement : SVGTextContentElement

@property(nonatomic,strong,readonly) SVGLength* /* FIXME: should be SVGAnimatedLengthList */ x;
@property(nonatomic,strong,readonly) SVGLength* /* FIXME: should be SVGAnimatedLengthList */ y;
@property(nonatomic,strong,readonly) SVGLength* /* FIXME: should be SVGAnimatedLengthList */ dx;
@property(nonatomic,strong,readonly) SVGLength* /* FIXME: should be SVGAnimatedLengthList */ dy;
@property(nonatomic,strong,readonly) SVGLength* /* FIXME: should be SVGAnimatedLengthList */ rotate;

@end
