/*!
 http://www.w3.org/TR/SVG/coords.html#InterfaceSVGTransform
 
 // Transform Types
 const unsigned short SVG_TRANSFORM_UNKNOWN = 0;
 const unsigned short SVG_TRANSFORM_MATRIX = 1;
 const unsigned short SVG_TRANSFORM_TRANSLATE = 2;
 const unsigned short SVG_TRANSFORM_SCALE = 3;
 const unsigned short SVG_TRANSFORM_ROTATE = 4;
 const unsigned short SVG_TRANSFORM_SKEWX = 5;
 const unsigned short SVG_TRANSFORM_SKEWY = 6;
 
 readonly attribute unsigned short type;
 readonly attribute SVGMatrix matrix;
 readonly attribute float angle;
 
 void setMatrix(in SVGMatrix matrix) raises(DOMException);
 void setTranslate(in float tx, in float ty) raises(DOMException);
 void setScale(in float sx, in float sy) raises(DOMException);
 void setRotate(in float angle, in float cx, in float cy) raises(DOMException);
 void setSkewX(in float angle) raises(DOMException);
 void setSkewY(in float angle) raises(DOMException);
*/
 
#import <Foundation/Foundation.h>

#import "SVGMatrix.h"

@interface SVGTransform : NSObject

/*! Transform Types */
typedef enum SVGKTransformType
{
	SVG_TRANSFORM_UNKNOWN = 0,
	SVG_TRANSFORM_MATRIX = 1,
	SVG_TRANSFORM_TRANSLATE = 2,
	SVG_TRANSFORM_SCALE = 3,
	SVG_TRANSFORM_ROTATE = 4,
	SVG_TRANSFORM_SKEWX = 5,
	SVG_TRANSFORM_SKEWY = 6
} SVGKTransformType;

@property(nonatomic) SVGKTransformType type;
@property(nonatomic,strong) SVGMatrix* matrix;
@property(nonatomic,readonly) float angle;

-(void) setMatrix:(SVGMatrix*) matrix;
-(void) setTranslate:(float) tx ty:(float) ty;
-(void) setScale:(float) sx sy:(float) sy;
-(void) setRotate:(float) angle cx:(float) cx cy:(float) cy;
-(void) setSkewX:(float) angle;
-(void) setSkewY:(float) angle;

@end
