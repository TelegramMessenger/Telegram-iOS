/**
 http://www.w3.org/TR/SVG/coords.html#InterfaceSVGAnimatedPreserveAspectRatio
 
 readonly attribute SVGPreserveAspectRatio baseVal;
 readonly attribute SVGPreserveAspectRatio animVal;
 */
#import <Foundation/Foundation.h>
#import "SVGPreserveAspectRatio.h"

@interface SVGAnimatedPreserveAspectRatio : NSObject

@property(nonatomic,strong) SVGPreserveAspectRatio* baseVal;
@property(nonatomic,strong, readonly) SVGPreserveAspectRatio* animVal;

@end
