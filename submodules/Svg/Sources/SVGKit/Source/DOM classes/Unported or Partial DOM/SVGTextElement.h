#import <Foundation/Foundation.h>

#import "SVGTextPositioningElement.h"
#import "ConverterSVGToCALayer.h"
#import "SVGTransformable.h"

/**
 http://www.w3.org/TR/2011/REC-SVG11-20110816/text.html#TextElement
 
 interface SVGTextElement : SVGTextPositioningElement, SVGTransformable
 */
@interface SVGTextElement : SVGTextPositioningElement <SVGTransformable, ConverterSVGToCALayer>

@end
