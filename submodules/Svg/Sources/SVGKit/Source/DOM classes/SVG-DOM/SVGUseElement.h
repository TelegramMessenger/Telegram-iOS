/*
 http://www.w3.org/TR/SVG/struct.html#InterfaceSVGUseElement
 
 interface SVGUseElement : SVGElement,
 SVGURIReference,
 SVGTests,
 SVGLangSpace,
 SVGExternalResourcesRequired,
 SVGStylable,
 SVGTransformable {
 readonly attribute SVGAnimatedLength x;
 readonly attribute SVGAnimatedLength y;
 readonly attribute SVGAnimatedLength width;
 readonly attribute SVGAnimatedLength height;
 readonly attribute SVGElementInstance instanceRoot;
 readonly attribute SVGElementInstance animatedInstanceRoot;
 };
 
 */
#import "SVGLength.h"
#import "SVGElement.h"

@class SVGElementInstance;
#import "SVGElementInstance.h"

#import "ConverterSVGToCALayer.h"
#import "SVGTransformable.h"

@interface SVGUseElement : SVGElement < SVGTransformable /*FIXME: delete this rubbish:*/, ConverterSVGToCALayer>

@property(nonatomic, strong, readonly) /*FIXME: should be SVGAnimatedLength instead*/ SVGLength* x;
@property(nonatomic, strong, readonly) /*FIXME: should be SVGAnimatedLength instead*/ SVGLength* y;
@property(nonatomic, strong, readonly) /*FIXME: should be SVGAnimatedLength instead*/ SVGLength* width;
@property(nonatomic, strong, readonly) /*FIXME: should be SVGAnimatedLength instead*/ SVGLength* height;
@property(nonatomic, strong, readonly) SVGElementInstance* instanceRoot;
@property(nonatomic, strong, readonly) SVGElementInstance* animatedInstanceRoot;

@end
