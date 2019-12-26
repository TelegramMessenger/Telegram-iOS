/*
 From SVG-DOM, via Core DOM:
 
 http://www.w3.org/TR/DOM-Level-2-Core/core.html#ID-FF21A306
 
 interface CharacterData : Node {
 attribute DOMString        data;
 // raises(DOMException) on setting
 // raises(DOMException) on retrieval
 
 readonly attribute unsigned long    length;
 DOMString          substringData(in unsigned long offset, 
 in unsigned long count)
 raises(DOMException);
 void               appendData(in DOMString arg)
 raises(DOMException);
 void               insertData(in unsigned long offset, 
 in DOMString arg)
 raises(DOMException);
 void               deleteData(in unsigned long offset, 
 in unsigned long count)
 raises(DOMException);
 void               replaceData(in unsigned long offset, 
 in unsigned long count, 
 in DOMString arg)
 raises(DOMException);
 };

 */

#import <Foundation/Foundation.h>

/** objc won't allow this: @class Node;*/
#import "Node.h"

@interface CharacterData : Node

@property(nonatomic,strong,readonly) NSString* data;
	
@property(nonatomic,readonly) unsigned long length;

-(NSString*) substringData:(unsigned long) offset count:(unsigned long) count;
-(void) appendData:(NSString*) arg;
-(void) insertData:(unsigned long) offset arg:(NSString*) arg;
-(void) deleteData:(unsigned long) offset count:(unsigned long) count;
-(void) replaceData:(unsigned long) offset count:(unsigned long) count arg:(NSString*) arg;

@end
