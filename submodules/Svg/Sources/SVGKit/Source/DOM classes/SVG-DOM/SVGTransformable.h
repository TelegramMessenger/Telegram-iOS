/**
 * http://www.w3.org/TR/SVG/types.html#InterfaceSVGTransformable
 
 interface SVGTransformable : SVGLocatable {
 readonly attribute SVGAnimatedTransformList transform;
 
 */

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

@protocol SVGTransformable <NSObject>

@property(nonatomic) CGAffineTransform transform; // FIXME: TODO: this should be a different type

@end
