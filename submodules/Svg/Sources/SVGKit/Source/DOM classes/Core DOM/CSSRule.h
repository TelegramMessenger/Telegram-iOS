/**
 http://www.w3.org/TR/2000/REC-DOM-Level-2-Style-20001113/css.html#CSS-CSSRule
 
 interface CSSRule {
 
 // RuleType
 const unsigned short      UNKNOWN_RULE                   = 0;
 const unsigned short      STYLE_RULE                     = 1;
 const unsigned short      CHARSET_RULE                   = 2;
 const unsigned short      IMPORT_RULE                    = 3;
 const unsigned short      MEDIA_RULE                     = 4;
 const unsigned short      FONT_FACE_RULE                 = 5;
 const unsigned short      PAGE_RULE                      = 6;
 
 readonly attribute unsigned short   type;
 attribute DOMString        cssText;
 // raises(DOMException) on setting
 
 readonly attribute CSSStyleSheet    parentStyleSheet;
 readonly attribute CSSRule          parentRule;
 */
#import <Foundation/Foundation.h>

@class CSSStyleSheet;

typedef enum CSSRuleType
{
	UNKNOWN_RULE                   = 0,
	STYLE_RULE                     = 1,
	CHARSET_RULE                   = 2,
	IMPORT_RULE                    = 3,
	MEDIA_RULE                     = 4,
	FONT_FACE_RULE                 = 5,
	PAGE_RULE                      = 6
} CSSRuleType;

@interface CSSRule : NSObject

@property(nonatomic) unsigned short type;
@property(nonatomic,strong) NSString* cssText;

@property(nonatomic,strong) CSSStyleSheet* parentStyleSheet;
@property(nonatomic,strong) CSSRule* parentRule;
	
@end
