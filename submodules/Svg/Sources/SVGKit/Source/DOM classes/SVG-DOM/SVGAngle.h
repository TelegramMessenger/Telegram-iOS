/*!
 SVGAngle
 
 http://www.w3.org/TR/SVG/types.html#InterfaceSVGAngle
 
 // Angle Unit Types
 const unsigned short SVG_ANGLETYPE_UNKNOWN = 0;
 const unsigned short SVG_ANGLETYPE_UNSPECIFIED = 1;
 const unsigned short SVG_ANGLETYPE_DEG = 2;
 const unsigned short SVG_ANGLETYPE_RAD = 3;
 const unsigned short SVG_ANGLETYPE_GRAD = 4;
 
 readonly attribute unsigned short unitType;
 attribute float value setraises(DOMException);
 attribute float valueInSpecifiedUnits setraises(DOMException);
 attribute DOMString valueAsString setraises(DOMException);
 
 void newValueSpecifiedUnits(in unsigned short unitType, in float valueInSpecifiedUnits) raises(DOMException);
 void convertToSpecifiedUnits(in unsigned short unitType) raises(DOMException);
 */
#import <Foundation/Foundation.h>

@interface SVGAngle : NSObject

/*! Angle Unit Types */
typedef enum SVGKAngleType
{
	SVG_ANGLETYPE_UNKNOWN = 0,
	SVG_ANGLETYPE_UNSPECIFIED = 1,
	SVG_ANGLETYPE_DEG = 2,
	SVG_ANGLETYPE_RAD = 3,
	SVG_ANGLETYPE_GRAD = 4
} SVGKAngleType;

@property(nonatomic, readonly) SVGKAngleType unitType;
@property(nonatomic) float value;
@property(nonatomic) float valueInSpecifiedUnits;
@property(nonatomic,strong) NSString* valueAsString;

-(void) newValueSpecifiedUnits:(SVGKAngleType) unitType valueInSpecifiedUnits:(float) valueInSpecifiedUnits;
-(void) convertToSpecifiedUnits:(SVGKAngleType) unitType;
@end
