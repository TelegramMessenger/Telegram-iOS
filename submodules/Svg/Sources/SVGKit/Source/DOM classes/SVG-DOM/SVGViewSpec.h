/*!
 SVGViewSpec
 
 interface SVGViewSpec : SVGZoomAndPan,
 SVGFitToViewBox {
 readonly attribute SVGTransformList transform;
 readonly attribute SVGElement viewTarget;
 readonly attribute DOMString viewBoxString;
 readonly attribute DOMString preserveAspectRatioString;
 readonly attribute DOMString transformString;
 readonly attribute DOMString viewTargetString;
 };
 */
#import <Foundation/Foundation.h>

@class SVGElement;
#import "SVGElement.h"

@interface SVGViewSpec : NSObject

/* FIXME: SVGTransformList not implemented yet: @property(nonatomic,readonly) SVGTransformList transform; */
@property(nonatomic,readonly) SVGElement* viewTarget;
@property(nonatomic,readonly) NSString* viewBoxString;
@property(nonatomic,readonly) NSString* preserveAspectRatioString;
@property(nonatomic,readonly) NSString* transformString;
@property(nonatomic,readonly) NSString* viewTargetString;

@end
