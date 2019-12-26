/**
 http://www.w3.org/TR/2000/REC-DOM-Level-2-Style-20001113/stylesheets.html#StyleSheets-StyleSheetList
 
 interface StyleSheetList {
 readonly attribute unsigned long    length;
 StyleSheet         item(in unsigned long index);
 */

#import <Foundation/Foundation.h>

#import "StyleSheet.h"

@interface StyleSheetList : NSObject

@property(nonatomic,readonly) unsigned long length;

-(StyleSheet*) item:(unsigned long) index;

@end
