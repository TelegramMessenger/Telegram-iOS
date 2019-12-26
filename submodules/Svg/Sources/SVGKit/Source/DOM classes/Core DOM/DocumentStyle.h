/**
 
 http://www.w3.org/TR/2000/REC-DOM-Level-2-Style-20001113/stylesheets.html#StyleSheets-StyleSheet-DocumentStyle
 
 interface DocumentStyle {
 readonly attribute StyleSheetList   styleSheets;
 */

#import <Foundation/Foundation.h>

#import "StyleSheetList.h"

@protocol DocumentStyle <NSObject>

@property(nonatomic,retain) StyleSheetList* styleSheets;

@end
