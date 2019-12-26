/**
 http://www.w3.org/TR/2000/REC-DOM-Level-2-Style-20001113/css.html#CSS-CSSStyleDeclaration
 
 interface CSSStyleDeclaration {
 attribute DOMString        cssText;
 // raises(DOMException) on setting
 
 DOMString          getPropertyValue(in DOMString propertyName);
 CSSValue           getPropertyCSSValue(in DOMString propertyName);
 DOMString          removeProperty(in DOMString propertyName)
 raises(DOMException);
 DOMString          getPropertyPriority(in DOMString propertyName);
 void               setProperty(in DOMString propertyName,
 in DOMString value,
 in DOMString priority)
 raises(DOMException);
 readonly attribute unsigned long    length;
 DOMString          item(in unsigned long index);
 readonly attribute CSSRule          parentRule;
 */
#import <Foundation/Foundation.h>

#import "CSSValue.h"
#import "CSSRule.h"

@interface CSSStyleDeclaration : NSObject

/** NOTE: requires special treatment!
 
 From spec:
 
 "The parsable textual representation of the declaration block (excluding the surrounding curly braces). Setting this attribute will result in the parsing of the new value and resetting of all the properties in the declaration block including the removal or addition of properties."
 */
@property(nonatomic,strong) NSString* cssText;

-(NSString*) getPropertyValue:(NSString*) propertyName;
-(CSSValue*) getPropertyCSSValue:(NSString*) propertyName;
-(NSString*) removeProperty:(NSString*) propertyName;

-(NSString*) getPropertyPriority:(NSString*) propertyName;
-(void) setProperty:(NSString*) propertyName value:(NSString*) value priority:(NSString*) priority;

@property(nonatomic) unsigned long length;

-(NSString*) item:(long) index;

@property(nonatomic,strong) CSSRule* parentRule;

@end
