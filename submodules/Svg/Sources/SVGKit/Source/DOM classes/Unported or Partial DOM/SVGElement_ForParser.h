#import "SVGElement.h"

#import "SVGKParseResult.h"

@interface SVGElement ()


+ (BOOL)shouldStoreContent; // to optimize parser, default is NO

- (void)loadDefaults; // should be overriden to set element defaults

/*! Overridden by sub-classes.  Be sure to call [super postProcessAttributesAddingErrorsTo:attributes];
 Returns nil, or an error if something failed trying to parse attributes (usually:
 unsupported SVG feature that's not implemented yet) 
 */
- (void)postProcessAttributesAddingErrorsTo:(SVGKParseResult *)parseResult;

@end
