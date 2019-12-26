/**
 http://www.w3.org/TR/2000/REC-DOM-Level-2-Style-20001113/css.html#CSS-CSSPrimitiveValue
 
 interface CSSPrimitiveValue : CSSValue {
 
 // UnitTypes
 const unsigned short      CSS_UNKNOWN                    = 0;
 const unsigned short      CSS_NUMBER                     = 1;
 const unsigned short      CSS_PERCENTAGE                 = 2;
 const unsigned short      CSS_EMS                        = 3;
 const unsigned short      CSS_EXS                        = 4;
 const unsigned short      CSS_PX                         = 5;
 const unsigned short      CSS_CM                         = 6;
 const unsigned short      CSS_MM                         = 7;
 const unsigned short      CSS_IN                         = 8;
 const unsigned short      CSS_PT                         = 9;
 const unsigned short      CSS_PC                         = 10;
 const unsigned short      CSS_DEG                        = 11;
 const unsigned short      CSS_RAD                        = 12;
 const unsigned short      CSS_GRAD                       = 13;
 const unsigned short      CSS_MS                         = 14;
 const unsigned short      CSS_S                          = 15;
 const unsigned short      CSS_HZ                         = 16;
 const unsigned short      CSS_KHZ                        = 17;
 const unsigned short      CSS_DIMENSION                  = 18;
 const unsigned short      CSS_STRING                     = 19;
 const unsigned short      CSS_URI                        = 20;
 const unsigned short      CSS_IDENT                      = 21;
 const unsigned short      CSS_ATTR                       = 22;
 const unsigned short      CSS_COUNTER                    = 23;
 const unsigned short      CSS_RECT                       = 24;
 const unsigned short      CSS_RGBCOLOR                   = 25;
 
 readonly attribute unsigned short   primitiveType;
 void               setFloatValue(in unsigned short unitType,
 in float floatValue)
 raises(DOMException);
 float              getFloatValue(in unsigned short unitType)
 raises(DOMException);
 void               setStringValue(in unsigned short stringType,
 in DOMString stringValue)
 raises(DOMException);
 DOMString          getStringValue()
 raises(DOMException);
 Counter            getCounterValue()
 raises(DOMException);
 Rect               getRectValue()
 raises(DOMException);
 RGBColor           getRGBColorValue()
 raises(DOMException);
 */
#import "CSSValue.h"

typedef enum CSSPrimitiveType
{
	CSS_UNKNOWN                    = 0,
	CSS_NUMBER                     = 1,
	CSS_PERCENTAGE                 = 2,
	CSS_EMS                        = 3,
	CSS_EXS                        = 4,
	CSS_PX                         = 5,
	CSS_CM                         = 6,
	CSS_MM                         = 7,
	CSS_IN                         = 8,
	CSS_PT                         = 9,
	CSS_PC                         = 10,
	CSS_DEG                        = 11,
	CSS_RAD                        = 12,
	CSS_GRAD                       = 13,
	CSS_MS                         = 14,
	CSS_S                          = 15,
	CSS_HZ                         = 16,
	CSS_KHZ                        = 17,
	CSS_DIMENSION                  = 18,
	CSS_STRING                     = 19,
	CSS_URI                        = 20,
	CSS_IDENT                      = 21,
	CSS_ATTR                       = 22,
	CSS_COUNTER                    = 23,
	CSS_RECT                       = 24,
	CSS_RGBCOLOR                   = 25
} CSSPrimitiveType;

@interface CSSPrimitiveValue : CSSValue

@property(nonatomic) CSSPrimitiveType primitiveType;

-(void) setFloatValue:(CSSPrimitiveType) unitType floatValue:(float) floatValue;

-(float) getFloatValue:(CSSPrimitiveType) unitType;

-(void) setStringValue:(CSSPrimitiveType) stringType stringValue:(NSString*) stringValue;

-(NSString*) getStringValue;

-(/* FIXME: have to add this type: Counter*/ void) getCounterValue;

-(/* FIXME: have to add this type: Rect*/ void) getRectValue;

-(/* FIXME: have to add this type: RGBColor*/ void) getRGBColorValue;

@end
