/**
 There are some shared methods in DOM specification, where two classes have the same method, but
 are NOT subclass/superclass of each other. This is very bad from OOP design POV, because it means
 we end up with copy/paste duplicated code, very VERY likely to gain long term bugs.

 Also, those methods REQUIRE a second, recursive, method or else you can't implement them easily.
 
 So, we move their implementations into this helper class, so they can share implementation.
 
 (c.f. Element vs Document - identical methods for getElementsByName)
 */
#import <Foundation/Foundation.h>

@class Node, NodeList, Element; // avoiding #import here, to avoid C header loop problems.

#define DEBUG_DOM_MATCH_ELEMENTS_IDS_AND_NAMES 0 // For debugging SVGKit: causes debug output on getElementById etc

@interface DOMHelperUtilities : NSObject

/*! This useful method provides both the DOM level 1 and the DOM level 2 implementations of searching the tree for a node - because THEY ARE DIFFERENT
 yet very similar
 */
+(void) privateGetElementsByName:(NSString*) name inNamespace:(NSString*) namespaceURI childrenOfElement:(Node*) parent addToList:(NodeList*) accumulator;

/*! This is used in multiple base classes in DOM 1 and DOM 2 where they do NOT have shared superclasses, so we have to implement it here in a separate
 clas as a standalone method */
+(Element*) privateGetElementById:(NSString*) idValue childrenOfElement:(Node*) parent;

@end
