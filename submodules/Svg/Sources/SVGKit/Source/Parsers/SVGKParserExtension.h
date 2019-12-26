/**
 SVGParserExtension.h
 
 A protocol that lets us split "parsing an SVG" into lots of smaller parsing classes
 
 PARSING
 ---
 Actual parsing of an SVG is split into three places:
 
 1. High level, XML parsing: SVGParser
 2. ALL THE REST, this class: parsing the structure of a document, and special XML tags: any class that extends "SVGParserExtension"
 
 */

#import <Foundation/Foundation.h>

#import "SVGKSource.h"

@class SVGKParseResult;
#import "SVGKParseResult.h"

#import "Node.h"

/*! Experimental: allow SVGKit parser-extensions to insert custom data into an SVGKParseResult */
#define ENABLE_PARSER_EXTENSIONS_CUSTOM_DATA 0

@protocol SVGKParserExtension <NSObject>

/*! Array of URI's as NSString's, one string for each XMLnamespace that this parser-extension can parse
 *
 * e.g. the main parser returns "[NSArray arrayWithObjects:@"http://www.w3.org/2000/svg", nil];"
 */
-(NSArray*) supportedNamespaces;

/*! Array of NSString's, one string for each XML tag (within a supported namespace!) that this parser-extension can parse
 *
 * e.g. the main parser returns "[NSArray arrayWithObjects:@"svg", @"title", @"defs", @"path", @"line", @"circle", ...etc... , nil];"
 */
-(NSArray*) supportedTags;

/*!
 Because SVG-DOM uses DOM, custom parsers can return any object they like - so long as its some kind of
 subclass of DOM's Node class
 */
- (Node*)handleStartElement:(NSString *)name document:(SVGKSource*) document namePrefix:(NSString*)prefix namespaceURI:(NSString*) XMLNSURI attributes:(NSMutableDictionary *)attributes parseResult:(SVGKParseResult*) parseResult parentNode:(Node*) parentNode;

/**
 Primarily used by the few nodes - <TEXT> and <TSPAN> - that need to post-process their text-content.
 In SVG, almost all data is stored in the attributes instead
 */
-(void)handleEndElement:(Node *)newNode document:(SVGKSource *)document parseResult:(SVGKParseResult *)parseResult;

@end
