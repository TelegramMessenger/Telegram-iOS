/**
 http://www.w3.org/TR/2000/REC-DOM-Level-2-Style-20001113/stylesheets.html#StyleSheets-MediaList
 
 interface MediaList {
 attribute DOMString        mediaText;
 // raises(DOMException) on setting
 
 readonly attribute unsigned long    length;
 DOMString          item(in unsigned long index);
 void               deleteMedium(in DOMString oldMedium)
 raises(DOMException);
 void               appendMedium(in DOMString newMedium)
 raises(DOMException);
*/

#import <Foundation/Foundation.h>

@interface MediaList : NSObject

@property(nonatomic,strong) NSString* mediaText;
@property(nonatomic) unsigned long length;

-(NSString*) item:(unsigned long) index;
-(void) deleteMedium:(NSString*) oldMedium;
-(void) appendMedium:(NSString*) newMedium;
	
@end
