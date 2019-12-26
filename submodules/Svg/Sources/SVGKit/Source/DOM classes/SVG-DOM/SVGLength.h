/*!
 SVGLength.h
 
 http://www.w3.org/TR/SVG/types.html#InterfaceSVGLength
 
 // Length Unit Types
 const unsigned short SVG_LENGTHTYPE_UNKNOWN = 0;
 const unsigned short SVG_LENGTHTYPE_NUMBER = 1;
 const unsigned short SVG_LENGTHTYPE_PERCENTAGE = 2;
 const unsigned short SVG_LENGTHTYPE_EMS = 3;
 const unsigned short SVG_LENGTHTYPE_EXS = 4;
 const unsigned short SVG_LENGTHTYPE_PX = 5;
 const unsigned short SVG_LENGTHTYPE_CM = 6;
 const unsigned short SVG_LENGTHTYPE_MM = 7;
 const unsigned short SVG_LENGTHTYPE_IN = 8;
 const unsigned short SVG_LENGTHTYPE_PT = 9;
 const unsigned short SVG_LENGTHTYPE_PC = 10;
 
 readonly attribute unsigned short unitType;
 attribute float value setraises(DOMException);
 attribute float valueInSpecifiedUnits setraises(DOMException);
 attribute DOMString valueAsString setraises(DOMException);
 
 void newValueSpecifiedUnits(in unsigned short unitType, in float valueInSpecifiedUnits) raises(DOMException);
 void convertToSpecifiedUnits(in unsigned short unitType) raises(DOMException);
 };
 */
#import <Foundation/Foundation.h>

typedef enum SVG_LENGTH_TYPE
{
	SVG_LENGTHTYPE_UNKNOWN = 0,
	SVG_LENGTHTYPE_NUMBER = 1,
	 SVG_LENGTHTYPE_PERCENTAGE = 2,
	 SVG_LENGTHTYPE_EMS = 3,
	 SVG_LENGTHTYPE_EXS = 4,
	 SVG_LENGTHTYPE_PX = 5,
	 SVG_LENGTHTYPE_CM = 6,
	 SVG_LENGTHTYPE_MM = 7,
	 SVG_LENGTHTYPE_IN = 8,
	 SVG_LENGTHTYPE_PT = 9,
	 SVG_LENGTHTYPE_PC = 10
} SVG_LENGTH_TYPE;


@interface SVGLength : NSObject

@property(nonatomic,readonly) SVG_LENGTH_TYPE unitType;
@property(nonatomic) float value;
@property(nonatomic) float valueInSpecifiedUnits;
@property(nonatomic,strong) NSString* valueAsString;
	
-(void) newValueSpecifiedUnits:(SVG_LENGTH_TYPE) unitType valueInSpecifiedUnits:(float) valueInSpecifiedUnits;
-(void) convertToSpecifiedUnits:(SVG_LENGTH_TYPE) unitType;

#pragma mark - things outside the spec but needed to make it usable in Objective C

+(SVGLength*) svgLengthZero;
+(SVGLength*) svgLengthFromNSString:(NSString*) s;

/** returns this SVGLength as if it had been converted to pixels, using [self convertToSpecifiedUnits:SVG_LENGTHTYPE_PX]
 */
-(float) pixelsValue;

/** to calculate relative values pass in the appropriate viewport dimension (width, height, or diagonal measure)
*/
-(float) pixelsValueWithDimension:(float)dimension;

/** to calculate relative gradient values pass in the appropriate viewport dimension (width, height)
 *  the different between this and `pixelsValueWithDimension` is that this one will treat number value which (0 <= value <= 1.0) as percent value and calculate the result. (used by gradient)
 */
-(float) pixelsValueWithGradientDimension:(float)dimension;

/** returns this SVGLength as if it had been converted to a raw number (USE pixelsValue instead, UNLESS you are dealing with something that you expect to be a percentage or
 similar non-pixel value), using [self convertToSpecifiedUnits:SVG_LENGTHTYPE_NUMBER]
 */
-(float) numberValue;

@end
