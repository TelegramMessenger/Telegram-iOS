//
//  SVGStyleParser.m
//  SVGPad
//
//  Created by Kevin Stich on 2/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SVGKParserStyles.h"

#import "CSSStyleSheet.h"
#import "StyleSheetList+Mutable.h"

@interface SVGKParserStyles ()
@property (nonatomic) NSArray *supportedNamespaces;
@property (nonatomic) NSArray *supportedTags;
@end

@implementation SVGKParserStyles

-(NSArray *)supportedNamespaces
{
    if( _supportedNamespaces == nil )
        _supportedNamespaces = @[@"http://www.w3.org/2000/svg"];
    return _supportedNamespaces;
}

-(NSArray *)supportedTags
{
    if( _supportedTags == nil )
        _supportedTags = @[@"style"];
    return _supportedTags;
}

-(Node *)handleStartElement:(NSString *)name document:(SVGKSource *)document namePrefix:(NSString *)prefix namespaceURI:(NSString *)XMLNSURI attributes:(NSMutableDictionary *)attributes parseResult:(SVGKParseResult *)parseResult parentNode:(Node *)parentNode
{
	if( [[self supportedNamespaces] containsObject:XMLNSURI] )
	{
		/**
		 
		 NB: this section of code is copy/pasted from SVGKParserDOM -- we don't want anything special, we want an ordinary DOM node,
		 ...but we need this standalone parser-extension because a <style> tag needs some custom *post-processing*
		 
		 
		 
		 */
		
		NSString* qualifiedName = (prefix == nil) ? name : [NSString stringWithFormat:@"%@:%@", prefix, name];
		
		/** NB: must supply a NON-qualified name if we have no specific prefix here ! */
		// FIXME: we always return an empty Element here; for DOM spec, should we be detecting things like "comment" nodes? I dont know how libxml handles those and sends them to us. I've never seen one in action...
		Element *blankElement = [[Element alloc] initWithQualifiedName:qualifiedName inNameSpaceURI:XMLNSURI attributes:attributes];
		
		return blankElement;
	}
	else
		return nil;
}

-(void)handleEndElement:(Node *)newNode document:(SVGKSource *)document parseResult:(SVGKParseResult *)parseResult
{
	/** This is where the magic happens ... */
		NSString* c = [newNode.textContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		if( c.length > 0 )
		{
			CSSStyleSheet* parsedStylesheet = [[CSSStyleSheet alloc] initWithString:c];
			
			[parseResult.parsedDocument.rootElement.styleSheets.internalArray addObject:parsedStylesheet];
		}

}

@end
