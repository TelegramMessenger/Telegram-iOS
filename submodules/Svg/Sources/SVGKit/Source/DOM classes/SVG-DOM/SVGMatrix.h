/*!
 
 http://www.w3.org/TR/SVG/coords.html#InterfaceSVGMatrix
 
 interface SVGMatrix {
 
 attribute float a setraises(DOMException);
 attribute float b setraises(DOMException);
 attribute float c setraises(DOMException);
 attribute float d setraises(DOMException);
 attribute float e setraises(DOMException);
 attribute float f setraises(DOMException);
 
 SVGMatrix multiply(in SVGMatrix secondMatrix);
 SVGMatrix inverse() raises(SVGException);
 SVGMatrix translate(in float x, in float y);
 SVGMatrix scale(in float scaleFactor);
 SVGMatrix scaleNonUniform(in float scaleFactorX, in float scaleFactorY);
 SVGMatrix rotate(in float angle);
 SVGMatrix rotateFromVector(in float x, in float y) raises(SVGException);
 SVGMatrix flipX();
 SVGMatrix flipY();
 SVGMatrix skewX(in float angle);
 SVGMatrix skewY(in float angle);
 };
 */

#import <Foundation/Foundation.h>

@interface SVGMatrix : NSObject

@property(nonatomic) float a;
@property(nonatomic) float b;
@property(nonatomic) float c;
@property(nonatomic) float d;
@property(nonatomic) float e;
@property(nonatomic) float f;

-(SVGMatrix*) multiply:(SVGMatrix*) secondMatrix;
-(SVGMatrix*) inverse;
-(SVGMatrix*) translate:(float) x y:(float) y;
-(SVGMatrix*) scale:(float) scaleFactor;
-(SVGMatrix*) scaleNonUniform:(float) scaleFactorX scaleFactorY:(float) scaleFactorY;
-(SVGMatrix*) rotate:(float) angle;
-(SVGMatrix*) rotateFromVector:(float) x y:(float) y;
-(SVGMatrix*) flipX;
-(SVGMatrix*) flipY;
-(SVGMatrix*) skewX:(float) angle;
-(SVGMatrix*) skewY:(float) angle;

@end
