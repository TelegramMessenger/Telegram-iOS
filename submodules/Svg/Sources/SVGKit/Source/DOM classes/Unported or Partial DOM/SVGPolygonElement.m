//
//  SVGPolygonElement.m
//  SVGKit
//
//  Copyright Matt Rajca 2011. All rights reserved.
//

#import "SVGPolygonElement.h"

#import "SVGKPointsAndPathsParser.h"

#import "SVGElement_ForParser.h" // to resolve Xcode circular dependencies; in long term, parsing SHOULD NOT HAPPEN inside any class whose name starts "SVG" (because those are reserved classes for the SVG Spec)

@interface SVGPolygonElement()

- (void) parseData:(NSString *)data;

@end

@implementation SVGPolygonElement

- (void)postProcessAttributesAddingErrorsTo:(SVGKParseResult *)parseResult {
	[super postProcessAttributesAddingErrorsTo:parseResult];
	
	[self parseData:[self getAttribute:@"points"]];
}

/*! According to SVG spec, a 'polygon' is EXACTYLY IDENTICAL to a 'path', if you prepend the letter "M", and
 postfix the letter 'z'.
 
 So, we take the complicated parser from SVGPathElement, remove all the multi-command stuff, and just use the
 "M" command
 */
- (void)parseData:(NSString *)data
{
	CGMutablePathRef path = CGPathCreateMutable();
    NSScanner* dataScanner = [NSScanner scannerWithString:data];
    
	NSCharacterSet* knownCommands = [NSCharacterSet characterSetWithCharactersInString:@""];
	
	NSString* cmdArgs = nil;
	[dataScanner scanUpToCharactersFromSet:knownCommands
													   intoString:&cmdArgs];
	
	NSString* commandWithParameters = [@"M" stringByAppendingString:cmdArgs];
	NSScanner* commandScanner = [NSScanner scannerWithString:commandWithParameters];
	
	
    SVGCurve lastCurve = [SVGKPointsAndPathsParser readMovetoDrawtoCommandGroups:commandScanner
                                                                            path:path
                                                                      relativeTo:CGPointZero
                                                                      isRelative:FALSE];
    
    [SVGKPointsAndPathsParser readCloseCommand:[NSScanner scannerWithString:@"z"]
                                          path:path
                                    relativeTo:lastCurve.p];
	
	self.pathForShapeInRelativeCoords = path;
	CGPathRelease(path);
}

/* reference
 http://www.w3.org/TR/2011/REC-SVG11-20110816/shapes.html#PointsBNF
 */

/*
 list-of-points:
 wsp* coordinate-pairs? wsp*
 coordinate-pairs:
 coordinate-pair
 | coordinate-pair comma-wsp coordinate-pairs
 coordinate-pair:
 coordinate comma-wsp coordinate
 | coordinate negative-coordinate
 coordinate:
 number
 number:
 sign? integer-constant
 | sign? floating-point-constant
 negative-coordinate:
 "-" integer-constant
 | "-" floating-point-constant
 comma-wsp:
 (wsp+ comma? wsp*) | (comma wsp*)
 comma:
 ","
 integer-constant:
 digit-sequence
 floating-point-constant:
 fractional-constant exponent?
 | digit-sequence exponent
 fractional-constant:
 digit-sequence? "." digit-sequence
 | digit-sequence "."
 exponent:
 ( "e" | "E" ) sign? digit-sequence
 sign:
 "+" | "-"
 digit-sequence:
 digit
 | digit digit-sequence
 digit:
 "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
 */

@end
