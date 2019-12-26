/*
 From SVG-DOM, via Core DOM:
 
 http://www.w3.org/TR/DOM-Level-2-Core/core.html#ID-11C98490
 
 interface EntityReference : Node {
 };
 */
#import <Foundation/Foundation.h>

/** objc won't allow this: @class Node; */
#import "Node.h"

@interface EntityReference : Node

@end
