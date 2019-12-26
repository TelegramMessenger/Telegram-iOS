/*
 SVG-DOM, via Core DOM:
 
 http://www.w3.org/TR/DOM-Level-2-Core/core.html#ID-1004215813
 
 interface ProcessingInstruction : Node {
 readonly attribute DOMString        target;
 attribute DOMString        data;
 // raises(DOMException) on setting
 
 };
*/

#import <Foundation/Foundation.h>

/** objc won't allow this: @class Node;*/
#import "Node.h"

@interface ProcessingInstruction : Node
@property(nonatomic,strong,readonly) NSString* target;
@property(nonatomic,strong,readonly) NSString* data;

-(id) initProcessingInstruction:(NSString*) target value:(NSString*) data;

@end
