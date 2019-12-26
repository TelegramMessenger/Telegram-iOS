/**
 SVGKParser.h
 
 The main parser for SVGKit. All the magic starts here. Either use:
 
    A: +parseSourceUsingDefaultSVGKParser
 
 ...or use:
 
    B: 1. -initWithSource:
    B: 2. -addDefaultSVGParserExtensions
	B: ...
    B: 3. (as many times as you need) -addParserExtension:
 	B: ...
    B: 4. -parseSynchronously
 
 Note that "A" above does ALL the steps in B for you. If you need a custom set of Parser Extensions, you'll need to
  do all the steps in B yourself
 
 
 PARSING
 ---
 Actual parsing of an SVG is split into three places:
 
 1. High level, XML parsing: this file (SVGKParser)
 2. Mid level, parsing the structure of a document, and special XML tags: any class that extends "SVGKParserExtension"
 3. Mid level, parsing SVG tags only: SVGKParserSVG (it's an extension that just does base SVG)
 4. Low level, parsing individual tags within a file, and precise co-ordinates: all the "SVG...Element" classes parse themselves
 
 IDEALLY, we'd like to change that to:
 
 1. High level, XML parsing: this file (SVGKParser)
 2. Mid level, parsing the structure of a document, and special XML tags: any class that extends "SVGKParserExtension"
 3. Mid level, parsing SVG tags only, but also handling all the different tags: SVGKParserSVG
 4. Lowest level, parsing co-ordinate lists, numbers, strings: yacc/lex parser (in an unnamed class that hasn't been written yet)
 */

#import <Foundation/Foundation.h>

#import "SVGKSource.h"
#import "SVGKParserExtension.h"
#import "SVGKParseResult.h"

#import "SVGElement.h"



/*! RECOMMENDED: leave this set to 1 to get warnings about "legal, but poorly written" SVG */
#define PARSER_WARN_FOR_ANONYMOUS_SVG_G_TAGS 1

/*! Verbose parser logging - ONLY needed if you have an SVG file that's failing to load / crashing */
#define DEBUG_VERBOSE_LOG_EVERY_TAG 0
#define DEBUG_XML_PARSER 0

@interface SVGKParser : NSObject {
  @private
	NSMutableString *_storedChars;
	//NSMutableArray *_elementStack;
	NSMutableArray * _stackOfParserExtensions;
	Node * _parentOfCurrentNode;
}

@property(nonatomic,strong,readonly) SVGKSource* source;
@property(nonatomic,strong,readonly) NSMutableArray* externalStylesheets;
@property(nonatomic,strong,readonly) SVGKParseResult* currentParseRun;

@property(nonatomic,strong) NSMutableArray* parserExtensions;
@property(nonatomic,strong) NSMutableDictionary* parserKnownNamespaces; /**< maps "uri" to "array of parser-extensions" */

#pragma mark - NEW

/**
 If you kept the SVGKParser instance when you started a parse, you can
 hand that instance to another thread and the OTHER thread can trigger
 a cancel.
 
 It is not instantaneous, but kicks in as soon as more data is read from
 the raw bytes-stream, so it's pretty quick
 */
+(void) cancelParser:(SVGKParser*) parserToCancel;

/**
 Creates an SVGKParser, and adds the "standard" extensions for parsing
 a standard SVG file; you can then add any of your own custom extensions
 before triggering the parse with e.g. "parseSynchronously"
 */
+(SVGKParser *) newParserWithDefaultSVGKParserExtensions:(SVGKSource *)source;

/**
 Delegates to [self newParserWithDefaultSVGKParserExtensions:], and then auto-starts
 the parse SYNCHRONOUSLY (may take anything from 0.001 seconds up to 30+ seconds
 for a huge SVG file).
 
 Returns the fully-parsed result, including any errors
 */
+ (SVGKParseResult*) parseSourceUsingDefaultSVGKParser:(SVGKSource*) source;

/**
 This MIGHT now be safe to call multiple times on different threads
 (NB: the only reason it wasn't safe before was major bugs in libxml
 that break libxml in horrible ways, see the source code to this class
 for more info)
 */
- (SVGKParseResult*) parseSynchronously;

+(NSDictionary *) NSDictionaryFromCSSAttributes: (Attr*) styleAttribute;



#pragma mark - OLD - POTENTIALLY DELETE THESE ONCE THEY'VE ALL BEEN CHECKED AND CONVERTED

- (id)initWithSource:(SVGKSource *)doc;

/*! Adds the default SVG-tag parsers (everything in the SVG namespace); you should always use these, unless you
 are massively customizing SVGKit's parser! */
-(void) addDefaultSVGParserExtensions;
/*! NB: you ALMOST ALWAYS want to first call "addDefaultSVGParserExtensions" */
- (void) addParserExtension:(NSObject<SVGKParserExtension>*) extension;



@end
