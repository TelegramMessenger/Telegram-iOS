/*!
 http://www.w3.org/TR/SVG/coords.html#InterfaceSVGPoint
 
 interface SVGPoint {
 
 attribute float x setraises(DOMException);
 attribute float y setraises(DOMException);
 
 SVGPoint matrixTransform(in SVGMatrix matrix);
 };
 */
#import <Foundation/Foundation.h>

#import "SVGMatrix.h"

@interface SVGPoint : NSObject

@property(nonatomic,readonly) float x, y;

-(SVGPoint*) matrixTransform:(SVGMatrix*) matrix;

@end
