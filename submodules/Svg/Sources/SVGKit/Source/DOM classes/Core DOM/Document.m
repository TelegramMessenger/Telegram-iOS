#import "Document.h"
#import "Document+Mutable.h"

#import "DOMHelperUtilities.h"

#import "NodeList+Mutable.h" // needed for access to underlying array, because SVG doesnt specify how lists are made mutable

@implementation Document

@synthesize doctype;
@synthesize implementation;
@synthesize documentElement;



-(Element*) createElement:(NSString*) tagName
{
	Element* newElement = [[Element alloc] initWithLocalName:tagName attributes:nil];
	
	SVGKitLogVerbose( @"[%@] WARNING: SVG Spec, missing feature: if there are known attributes with default values, Attr nodes representing them SHOULD BE automatically created and attached to the element.", [self class] );
	
	return newElement;
}

-(DocumentFragment*) createDocumentFragment
{
	return [[DocumentFragment alloc] init];
}

-(Text*) createTextNode:(NSString*) data
{
	return [[Text alloc] initWithValue:data];
}

-(Comment*) createComment:(NSString*) data
{
	return [[Comment alloc] initWithValue:data];
}

-(CDATASection*) createCDATASection:(NSString*) data
{
	return [[CDATASection alloc] initWithValue:data];
}

-(ProcessingInstruction*) createProcessingInstruction:(NSString*) target data:(NSString*) data
{
	return [[ProcessingInstruction alloc] initProcessingInstruction:target value:data];
}

-(Attr*) createAttribute:(NSString*) n
{
	return [[Attr alloc] initWithName:n value:@""];
}

-(EntityReference*) createEntityReference:(NSString*) data
{
	NSAssert( FALSE, @"Not implemented. According to spec: Creates an EntityReference object. In addition, if the referenced entity is known, the child list of the EntityReference  node is made the same as that of the corresponding Entity  node. Note: If any descendant of the Entity node has an unbound namespace prefix, the corresponding descendant of the created EntityReference node is also unbound; (its namespaceURI is null). The DOM Level 2 does not support any mechanism to resolve namespace prefixes." );
	return nil;
}

-(NodeList*) getElementsByTagName:(NSString*) data
{
	NodeList* accumulator = [[NodeList alloc] init];
	[DOMHelperUtilities privateGetElementsByName:data inNamespace:nil childrenOfElement:self.documentElement addToList:accumulator];
	
	return accumulator;
}

// Introduced in DOM Level 2:
-(Node*) importNode:(Node*) importedNode deep:(BOOL) deep
{
	NSAssert( FALSE, @"Not implemented." );
	return nil;
}

// Introduced in DOM Level 2:
-(Element*) createElementNS:(NSString*) namespaceURI qualifiedName:(NSString*) qualifiedName
{
	Element* newElement = [[Element alloc] initWithQualifiedName:qualifiedName inNameSpaceURI:namespaceURI attributes:nil];
	
	SVGKitLogVerbose( @"[%@] WARNING: SVG Spec, missing feature: if there are known attributes with default values, Attr nodes representing them SHOULD BE automatically created and attached to the element.", [self class] );
	
	return newElement;
}

// Introduced in DOM Level 2:
-(Attr*) createAttributeNS:(NSString*) namespaceURI qualifiedName:(NSString*) qualifiedName
{
	NSAssert( FALSE, @"This should be re-implemented to share code with createElementNS: method above" );
	Attr* newAttr = [[Attr alloc] initWithNamespace:namespaceURI qualifiedName:qualifiedName value:@""];
	return newAttr;
}

// Introduced in DOM Level 2:
-(NodeList*) getElementsByTagNameNS:(NSString*) namespaceURI localName:(NSString*) localName
{
	NodeList* accumulator = [[NodeList alloc] init];
	[DOMHelperUtilities privateGetElementsByName:localName inNamespace:namespaceURI childrenOfElement:self.documentElement addToList:accumulator];
	
	return accumulator;
}

// Introduced in DOM Level 2:
-(Element*) getElementById:(NSString*) elementId
{
	return [DOMHelperUtilities privateGetElementById:elementId childrenOfElement:self.documentElement];
}

@end
