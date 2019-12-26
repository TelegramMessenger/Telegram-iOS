/**
 http://www.w3.org/TR/SVG/struct.html#InterfaceSVGGElement
 
 interface SVGGElement : SVGElement,
 SVGTests,
 SVGLangSpace,
 SVGExternalResourcesRequired,
 SVGStylable,
 SVGTransformable {
 */

#import "SVGElement.h"
#import "SVGElement_ForParser.h"

#import "ConverterSVGToCALayer.h"
#import "SVGTransformable.h"


@interface SVGGElement : SVGElement <SVGTransformable, SVGStylable, ConverterSVGToCALayer >

@end
