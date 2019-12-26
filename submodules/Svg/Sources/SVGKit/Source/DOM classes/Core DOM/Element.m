#import "Element.h"

#import "NamedNodeMap.h"
#import "DOMHelperUtilities.h"

@interface Element()
@property(nonatomic,strong,readwrite) NSString* tagName;
@end

@implementation Element

@synthesize tagName;


- (id)initWithLocalName:(NSString*) n attributes:(NSMutableDictionary*) attributes {
    self = [super initType:DOMNodeType_ELEMENT_NODE name:n];
    if (self) {
        self.tagName = n;
		
		for( NSString* attributeName in attributes.allKeys )
		{
			[self setAttribute:attributeName value:[attributes objectForKey:attributeName]];
		}
    }
    return self;
}
- (id)initWithQualifiedName:(NSString*) n inNameSpaceURI:(NSString*) nsURI attributes:(NSMutableDictionary *)attributes
{
    self = [super initType:DOMNodeType_ELEMENT_NODE name:n inNamespace:nsURI];
    if (self) {
        self.tagName = n;
		
		for( Attr* attribute in attributes.allValues )
		{
			[self.attributes setNamedItemNS:attribute inNodeNamespace:nsURI];
		}
    }
    return self;
}

-(NSString*) getAttribute:(NSString*) name
{
	/**
	 WARNING: the definition in the spec WILL CORRUPT unsuspecting Objective-C code (including a lot of the original SVGKit code!).
	 
	 The spec - instead of defining 'nil' - defines "" (empty string) as the
	 correct response.
	 
	 But in most of the modern, C-based, (non-scripting) languages, "" means 0.
	 
	 Very dangerous!
	 */
	Attr* result = (Attr*) [self.attributes getNamedItem:name];
	
	if( result == nil || result.value == nil )
		return @""; // according to spec
	else
		return result.value;
}

-(void) setAttribute:(NSString*) name value:(NSString*) value
{
	Attr* att = [[Attr alloc] initWithName:name value:value];
	
	[self.attributes setNamedItem:att];
}

-(void) removeAttribute:(NSString*) name
{
	[self.attributes removeNamedItem:name];
	
	NSAssert( FALSE, @"Not fully implemented. Spec says: If the removed attribute is known to have a default value, an attribute immediately appears containing the default value as well as the corresponding namespace URI, local name, and prefix when applicable." );
}

-(Attr*) getAttributeNode:(NSString*) name
{
	return (Attr*) [self.attributes getNamedItem:name];
}

-(Attr*) setAttributeNode:(Attr*) newAttr
{
	Attr* oldAtt = (Attr*) [self.attributes getNamedItem:newAttr.nodeName];
	
	[self.attributes setNamedItem:newAttr];
	
	return oldAtt;
}

-(Attr*) removeAttributeNode:(Attr*) oldAttr
{
	[self.attributes removeNamedItem:oldAttr.nodeName];
	
	NSAssert( FALSE, @"Not fully implemented. Spec: If the removed Attr  has a default value it is immediately replaced. The replacing attribute has the same namespace URI and local name, as well as the original prefix, when applicable. " );
	
	return oldAttr;
}

-(NodeList*) getElementsByTagName:(NSString*) name
{
	NodeList* accumulator = [[NodeList alloc] init];
	[DOMHelperUtilities privateGetElementsByName:name inNamespace:nil childrenOfElement:self addToList:accumulator];
	
	return accumulator;
}

// Introduced in DOM Level 2:
-(NSString*) getAttributeNS:(NSString*) namespaceURI localName:(NSString*) localName
{
	Attr* result = (Attr*) [self.attributes getNamedItemNS:namespaceURI localName:localName];
	
	if( result == nil || result.value == nil )
		return @""; // according to spec
	else
		return result.value;
}

// Introduced in DOM Level 2:
-(void) setAttributeNS:(NSString*) namespaceURI qualifiedName:(NSString*) qualifiedName value:(NSString*) value
{
	Attr* att = [[Attr alloc] initWithNamespace:namespaceURI qualifiedName:qualifiedName value:value];
	
	[self.attributes setNamedItemNS:att];
}

// Introduced in DOM Level 2:
-(void) removeAttributeNS:(NSString*) namespaceURI localName:(NSString*) localName
{
	NSAssert( FALSE, @"Not implemented yet" );
}

// Introduced in DOM Level 2:
-(Attr*) getAttributeNodeNS:(NSString*) namespaceURI localName:(NSString*) localName
{
	Attr* result = (Attr*) [self.attributes getNamedItemNS:namespaceURI localName:localName];
	
	return result;
}

// Introduced in DOM Level 2:
-(Attr*) setAttributeNodeNS:(Attr*) newAttr
{
	NSAssert( FALSE, @"Not implemented yet" );
	return nil;
}

// Introduced in DOM Level 2:
-(NodeList*) getElementsByTagNameNS:(NSString*) namespaceURI localName:(NSString*) localName
{
	NodeList* accumulator = [[NodeList alloc] init];
	[DOMHelperUtilities privateGetElementsByName:localName inNamespace:namespaceURI childrenOfElement:self addToList:accumulator];
	
	return accumulator;
}

// Introduced in DOM Level 2:
-(BOOL) hasAttribute:(NSString*) name
{
	Attr* result = (Attr*) [self.attributes getNamedItem:name];
	
	return result != nil;
}

// Introduced in DOM Level 2:
-(BOOL) hasAttributeNS:(NSString*) namespaceURI localName:(NSString*) localName
{
	NSAssert( FALSE, @"Not implemented yet" );
	return FALSE;
}

@end
