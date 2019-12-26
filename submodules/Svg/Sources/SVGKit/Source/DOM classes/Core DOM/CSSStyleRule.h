/**
 http://www.w3.org/TR/2000/REC-DOM-Level-2-Style-20001113/css.html#CSS-CSSStyleRule
 
 interface CSSStyleRule : CSSRule {
 attribute DOMString        selectorText;
 // raises(DOMException) on setting
 
 readonly attribute CSSStyleDeclaration  style;
 */
#import <Foundation/Foundation.h>

#import "CSSRule.h"
#import "CSSStyleDeclaration.h"

@interface CSSStyleRule : CSSRule

@property(nonatomic,strong) NSString* selectorText;
@property(nonatomic,strong) CSSStyleDeclaration* style;

#pragma mark - methods needed for ObjectiveC implementation

- (id)initWithSelectorText:(NSString*) selector styleText:(NSString*) styleText;

@end
