/*
 PLEASE NOTE: Apple has made a PRIVATE implementation of this class, and because of their
 stupid App Store rules they ban everyone else in the world from using a class with the
 same name. Instead of making the class public, they have stolen it out of the global
 namespace. This is the wrong thing to do, but we are required to rename our classes
 because of this.
 
 SVG-DOM, via Core DOM:
 
 http://www.w3.org/TR/DOM-Level-2-Core/core.html#ID-102161490
 
 interface DOMImplementation {
 boolean            hasFeature(in DOMString feature, 
 in DOMString version);
 // Introduced in DOM Level 2:
 DocumentType       createDocumentType(in DOMString qualifiedName, 
 in DOMString publicId, 
 in DOMString systemId)
 raises(DOMException);
 // Introduced in DOM Level 2:
 Document           createDocument(in DOMString namespaceURI, 
 in DOMString qualifiedName, 
 in DocumentType doctype)
 raises(DOMException);
 };
*/

#import <Foundation/Foundation.h>

#import "DocumentType.h"

@interface AppleSucksDOMImplementation : NSObject

-(BOOL) hasFeature:(NSString*) feature version:(NSString*) version;

// Introduced in DOM Level 2:
-(DocumentType*) createDocumentType:(NSString*) qualifiedName publicId:(NSString*) publicId systemId:(NSString*) systemId;

// Introduced in DOM Level 2:
-(Document*) createDocument:(NSString*) namespaceURI qualifiedName:(NSString*) qualifiedName doctype:(DocumentType*) doctype;

@end
