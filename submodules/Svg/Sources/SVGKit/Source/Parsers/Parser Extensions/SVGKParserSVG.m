#import "SVGKParserSVG.h"

#import "SVGSVGElement.h"
#import "SVGCircleElement.h"
#import "SVGClipPathElement.h"
#import "SVGDefsElement.h"
#import "SVGDescriptionElement.h"
//#import "SVGKSource.h"
#import "SVGEllipseElement.h"
#import "SVGGElement.h"
#import "SVGImageElement.h"
#import "SVGLineElement.h"
#import "SVGPathElement.h"
#import "SVGPolygonElement.h"
#import "SVGPolylineElement.h"
#import "SVGRectElement.h"
#import "SVGSwitchElement.h"
#import "SVGTitleElement.h"
#import "SVGTextElement.h"
#import "TinySVGTextAreaElement.h"

#import "SVGDocument_Mutable.h"

@interface SVGKParserSVG ()
@property (nonatomic) NSArray *supportedNamespaces;
@property (nonatomic) NSDictionary *elementMap;
@end

@implementation SVGKParserSVG

- (NSDictionary *)elementMap {
    if (!_elementMap) {
        _elementMap = [NSDictionary dictionaryWithObjectsAndKeys:
                      [SVGSVGElement class], @"svg",
                      [SVGCircleElement class], @"circle",
                      [SVGDescriptionElement class], @"description",
                      [SVGEllipseElement class], @"ellipse",
                      [SVGGElement class], @"g",
                      [SVGClipPathElement class], @"clipPath",
                      [SVGImageElement class], @"image",
                      [SVGLineElement class], @"line",
                      [SVGPathElement class], @"path",
                      [SVGPolygonElement class], @"polygon",
                      [SVGPolylineElement class], @"polyline",
                      [SVGRectElement class], @"rect",
                      [SVGSwitchElement class], @"switch",
                      [SVGTitleElement class], @"title",
                      [SVGTextElement class], @"text",
                      [TinySVGTextAreaElement class], @"textArea",
                      nil];
    }
    return _elementMap;
}

-(NSArray *)supportedNamespaces
{
    if( _supportedNamespaces == nil )
        _supportedNamespaces = @[@"http://www.w3.org/2000/svg"];
    return _supportedNamespaces;
}

/** "tags supported" is exactly the set of all SVGElement subclasses that already exist */
-(NSArray*) supportedTags
{
    return [self.elementMap allKeys];
}

- (Node*) handleStartElement:(NSString *)name document:(SVGKSource*) SVGKSource namePrefix:(NSString*)prefix namespaceURI:(NSString*) XMLNSURI attributes:(NSMutableDictionary *)attributes parseResult:(SVGKParseResult *)parseResult parentNode:(Node*) parentNode
{
	if( [[self supportedNamespaces] containsObject:XMLNSURI] )
	{
		Class elementClass = [self.elementMap objectForKey:name];
		
		if (!elementClass) {
			elementClass = [SVGElement class];
			SVGKitLogWarn(@"Support for '%@' element has not been implemented", name);
		}
		
		/**
		 NB: following the SVG Spec, it's critical that we ONLY use the DOM methods for creating
		 basic 'Element' nodes.
		 
		 Our SVGElement root class has an implementation of init that delegates to the same
		 private methods that the DOM methods use, so it's safe...
		 
		 FIXME: ...but in reality we ought to be using the DOMDocument createElement/NS methods, although "good luck" trying to find a DOMDocument if your SVG is embedded inside a larger XML document :(
		 */
		
		
		NSString* qualifiedName = (prefix == nil) ? name : [NSString stringWithFormat:@"%@:%@", prefix, name];
		/** NB: must supply a NON-qualified name if we have no specific prefix here ! */
		SVGElement *element = [[elementClass alloc] initWithQualifiedName:qualifiedName inNameSpaceURI:XMLNSURI attributes:attributes];
		
		/** NB: all the interesting handling of shared / generic attributes - e.g. the whole of CSS styling etc - takes place in this method: */
		[element postProcessAttributesAddingErrorsTo:parseResult];
		
		/** special case: <svg:svg ... version="XXX"> */
		if( [@"svg" isEqualToString:name] )
		{
            ((SVGSVGElement *) element).source = SVGKSource;
            
			NSString* svgVersion = nil;
			
			/** According to spec, if the first XML node is an SVG node, then it
			 becomes TWO THINGS:
			 
			 - An SVGSVGElement
			 *and*
			 - An SVGDocument
			 - ...and that becomes "the root SVGDocument"
			 
			 If it's NOT the first XML node, but it's the first SVG node, then it ONLY becomes:
			 
			 - An SVGSVGElement
			 
			 If it's NOT the first SVG node, then it becomes:
			 
			 - An SVGSVGElement
			 *and*
			 - An SVGDocument
			 
			 Yes. It's Very confusing! Go read the SVG Spec!
			 */
			
			BOOL generateAnSVGDocument = FALSE;
			BOOL overwriteRootSVGDocument = FALSE;
			BOOL overwriteRootOfTree = FALSE;
			
			if( parentNode == nil )
			{
				/** This start element is the first item in the document
				 PS: xcode has a new bug for Lion: it can't format single-line comments with two asterisks. This line added because Xcode sucks.
				 */
				generateAnSVGDocument = overwriteRootSVGDocument = overwriteRootOfTree = TRUE;
				
			}
			else if( parseResult.rootOfSVGTree == nil )
			{
				/** It's not the first XML, but it's the first SVG node */
				overwriteRootOfTree = TRUE;
			}
			else
			{
				/** It's not the first SVG node */
				// ... so: do nothing special
			}
			
			/**
			 Handle the complex stuff above about SVGDocument and SVG node
			 */
			if( overwriteRootOfTree )
			{
				parseResult.rootOfSVGTree = (SVGSVGElement*) element;
				
				/** Post-processing of the ROOT SVG ONLY (doesn't apply to embedded SVG's )
				 */
				if ((svgVersion = [attributes objectForKey:@"version"])) {
					SVGKSource.svgLanguageVersion = svgVersion;
				}
			}
			if( generateAnSVGDocument )
			{
				NSAssert( [element isKindOfClass:[SVGSVGElement class]], @"Trying to create a new internal SVGDocument from a Node that is NOT of type SVGSVGElement (tag: svg). Node was of type: %@", NSStringFromClass([element class]));
				
				SVGDocument* newDocument = [[SVGDocument alloc] init];
				newDocument.rootElement = (SVGSVGElement*) element;
				
				if( overwriteRootSVGDocument )
				{
					parseResult.parsedDocument = newDocument;
				}
				else
				{
					NSAssert( FALSE, @"Currently not supported: multiple SVG Document nodes in a single SVG file" );
				}
			}
			
		}
		
		
		return element;
	}
	
	return nil;
}

-(void)handleEndElement:(Node *)newNode document:(SVGKSource *)document parseResult:(SVGKParseResult *)parseResult
{
	
}

@end
