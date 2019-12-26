/*
 SVG-DOM, via Core DOM:
 
 http://www.w3.org/TR/DOM-Level-2-Core/core.html#ID-637646024
 
 interface Attr : Node {
 readonly attribute DOMString        name;
 readonly attribute boolean          specified;
 attribute DOMString        value;
 // raises(DOMException) on setting
 
 // Introduced in DOM Level 2:
 readonly attribute Element          ownerElement;
 };
*/
#import <Foundation/Foundation.h>

/** objc won't allow this: @class Node;*/
#import "Node.h"
@class Element;

@interface Attr : Node

/*! NB: The official DOM spec FAILS TO SPECIFY what the value of "name" is */
@property(nonatomic,strong,readonly) NSString* name;
@property(nonatomic,readonly) BOOL specified;
@property(nonatomic,strong,readonly) NSString* value;

// Introduced in DOM Level 2:
@property(nonatomic,strong,readonly) Element* ownerElement;

#pragma mark - ObjC methods

- (id)initWithName:(NSString*) n value:(NSString*) v;
- (id)initWithNamespace:(NSString*) ns qualifiedName:(NSString*) qn value:(NSString*) v;

@end
