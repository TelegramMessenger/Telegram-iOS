#import "SVGKParserDefsAndUse.h"

#import "Node.h"
#import "SVGKSource.h"
#import "SVGKParseResult.h"

#import "SVGDefsElement.h"
#import "SVGUseElement.h"
#import "SVGUseElement_Mutable.h"
#import "SVGElementInstance.h"
#import "SVGElementInstance_Mutable.h"
#import "SVGElementInstanceList.h"
#import "SVGElement_ForParser.h"

@implementation SVGKParserDefsAndUse

-(NSArray*) supportedNamespaces
{
	return [NSArray arrayWithObjects:
			@"http://www.w3.org/2000/svg",
			nil];
}

/** "tags supported" is exactly the set of all SVGElement subclasses that already exist */
-(NSArray*) supportedTags
{
	return [NSMutableArray arrayWithObjects: @"defs", @"use", nil];
}

-(SVGElementInstance*) convertSVGElementToElementInstanceTree:(SVGElement*) original outermostUseElement:(SVGUseElement*) outermostUseElement
{
	SVGElementInstance* instance = [[SVGElementInstance alloc] init];
	instance.correspondingElement = original;
	instance.correspondingUseElement = outermostUseElement;
	
	for( Node* subNode in original.childNodes )
	{
		if( [subNode isKindOfClass:[SVGElement class]])
		{
			SVGElement* subElement = (SVGElement*) subNode;
			
			SVGElementInstance *newSubInstance = [self convertSVGElementToElementInstanceTree:subElement outermostUseElement:outermostUseElement];
			
			newSubInstance.parentNode = instance; // side-effect: automatically adds sub as child
		}
	}
	
	return instance;
}

- (Node*) handleStartElement:(NSString *)name document:(SVGKSource*) SVGKSource namePrefix:(NSString*)prefix namespaceURI:(NSString*) XMLNSURI attributes:(NSMutableDictionary *)attributes parseResult:(SVGKParseResult *)parseResult parentNode:(Node*) parentNode
{
	if( [[self supportedNamespaces] containsObject:XMLNSURI] )
	{	
		NSString* qualifiedName = (prefix == nil) ? name : [NSString stringWithFormat:@"%@:%@", prefix, name];
		
		if( [name isEqualToString:@"defs"])
		{	
			/** NB: must supply a NON-qualified name if we have no specific prefix here ! */
			SVGDefsElement *element = [[SVGDefsElement alloc] initWithQualifiedName:qualifiedName inNameSpaceURI:XMLNSURI attributes:attributes];
			
			return element;
		}
		else if( [name isEqualToString:@"use"])
		{	
			/** NB: must supply a NON-qualified name if we have no specific prefix here ! */
			SVGUseElement *useElement = [[SVGUseElement alloc] initWithQualifiedName:qualifiedName inNameSpaceURI:XMLNSURI attributes:attributes];
			
			[useElement postProcessAttributesAddingErrorsTo:parseResult]; // handles "transform" and "style"
			
			if( [attributes valueForKey:@"x"] != nil )
				useElement.x = [SVGLength svgLengthFromNSString:[((Attr*)[attributes valueForKey:@"x"]) value]];
			if( [attributes valueForKey:@"y"] != nil )
				useElement.y = [SVGLength svgLengthFromNSString:[((Attr*)[attributes valueForKey:@"y"]) value]];
			if( [attributes valueForKey:@"width"] != nil )
				useElement.width = [SVGLength svgLengthFromNSString:[((Attr*)[attributes valueForKey:@"width"]) value]];
			if( [attributes valueForKey:@"height"] != nil )
				useElement.height = [SVGLength svgLengthFromNSString:[((Attr*)[attributes valueForKey:@"height"]) value]];
			
			NSString* hrefAttribute = [useElement getAttributeNS:@"http://www.w3.org/1999/xlink" localName:@"href"];
			
			NSAssert( [hrefAttribute length] > 0, @"Found an SVG <use> tag that has no 'xlink:href' attribute. File is invalid / don't know how to parse this" );
			if( [hrefAttribute length] > 0 )
			{
				NSString* linkHref = [((Attr*)[attributes valueForKey:@"xlink:href"]) value];
                /** support `url(#id) funcIRI as well to follow SVG spec` */
                if ([linkHref hasPrefix:@"url"]) {
                    NSRange range = NSMakeRange(4, linkHref.length - 5);
                    linkHref = [linkHref substringWithRange:range];
                }
                 
                NSAssert( [linkHref hasPrefix:@"#"], @"Not supported: <use> tags that declare an href to something that DOESN'T begin with #. Href supplied = %@", linkHref );
				
				linkHref = [linkHref substringFromIndex:1];
				
				/** have to find the node in the DOM tree with id = xlink:href's value */
				SVGElement* linkedElement = (SVGElement*) [parseResult.parsedDocument getElementById:linkHref];
				
				NSAssert( linkedElement != nil, @"Found an SVG <use> tag that points to a non-existent element. Missing element: id = %@", linkHref );
				
				
				useElement.instanceRoot = [self convertSVGElementToElementInstanceTree:linkedElement outermostUseElement:useElement];
			}
			
			return useElement;
		}
	}
	
	return nil;
}

-(void)handleEndElement:(Node *)newNode document:(SVGKSource *)document parseResult:(SVGKParseResult *)parseResult
{
	
}

@end
