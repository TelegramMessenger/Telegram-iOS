/**
 http://www.w3.org/TR/2000/REC-DOM-Level-2-Style-20001113/css.html#CSS-CSSRuleList
 
 interface CSSRuleList {
 readonly attribute unsigned long    length;
 CSSRule            item(in unsigned long index);
 */
#import <Foundation/Foundation.h>

#import "CSSRule.h"

@interface CSSRuleList : NSObject

@property(nonatomic,readonly) unsigned long length;

-(CSSRule*) item:(unsigned long) index;

@end
