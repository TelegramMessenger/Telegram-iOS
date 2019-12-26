/**
 According to the DOM spec, all nodes in an XML document must be parsed; if we lack specific information for them,
 i.e. if we have no other, more specific, parser - then we must parse them as the most basic objects, i.e. Node,
 Element, etc
 
 This is a special, magical parser that matches "no namespace" - i.e. matches what happens when no namspace was declared\
 */
#import <Foundation/Foundation.h>
#import "SVGKParserExtension.h"

@interface SVGKParserDOM : NSObject <SVGKParserExtension>

@end
