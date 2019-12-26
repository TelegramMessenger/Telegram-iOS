#import "CSSStyleSheet.h"

#import "CSSRuleList+Mutable.h"

#import "CSSStyleRule.h"

@implementation CSSStyleSheet

@synthesize ownerRule;
@synthesize cssRules;


/**
 Used to insert a new rule into the style sheet. The new rule now becomes part of the cascade.

 Parameters
 
 rule of type DOMString
 The parsable text representing the rule. For rule sets this contains both the selector and the style declaration. For at-rules, this specifies both the at-identifier and the rule content.
 index of type unsigned long
 The index within the style sheet's rule list of the rule before which to insert the specified rule. If the specified index is equal to the length of the style sheet's rule collection, the rule will be added to the end of the style sheet.
 
 Return Value
 
 unsigned long The index within the style sheet's rule collection of the newly inserted rule.
 */
-(long)insertRule:(NSString *)rule index:(unsigned long)index
{
	if( index == self.cssRules.length )
		index = self.cssRules.length + 1; // forces it to insert "before the one that doesn't exist" (stupid API design!)
	
	NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	rule = [rule stringByTrimmingCharactersInSet:whitespaceSet];
	
	//             SVGKitLogVerbose(@"A substringie %@", idStyleString);
	
	NSArray* stringSplitContainer = [rule componentsSeparatedByString:@"{"];
	if( [stringSplitContainer count] >= 2 ) //not necessary unless using shitty svgs
	{
		CSSStyleRule* newRule = [[CSSStyleRule alloc] initWithSelectorText:[stringSplitContainer objectAtIndex:0] styleText:[stringSplitContainer objectAtIndex:1]];
		
		[self.cssRules.internalArray insertObject:newRule atIndex:index-1]; // CSS says you insert "BEFORE" the index, which is the opposite of most C-based programming languages
		
		return index-1;
	}
	else
		NSAssert(FALSE, @"No idea what to do here");
	
	
	return -1; // failed, assert fired!
}

-(void)deleteRule:(unsigned long)index
{
	[self.cssRules.internalArray removeObjectAtIndex:index];
}

#pragma mark - methods needed for ObjectiveC implementation

- (id)initWithString:(NSString*) styleSheetBody
{
    self = [super init];
    if (self)
	{
		self.cssRules = [[CSSRuleList alloc]init];
		@autoreleasepool { //creating lots of autoreleased strings, not helpful for older devices
			
			/**
			 We have to manually handle the "ignore anything that is between / *  and * / because those are comments"
			 
			 NB: you NEED the NSRegularExpressionDotMatchesLineSeparators argument - which Apple DOES NOT HONOUR in NSString - hence have to use NSRegularExpression
			 */
			NSError* error;
			NSRegularExpression* regexp = [NSRegularExpression regularExpressionWithPattern:@"/\\*.*?\\*/" options: NSRegularExpressionDotMatchesLineSeparators error:&error];
			styleSheetBody = [regexp stringByReplacingMatchesInString:styleSheetBody options:0 range:NSMakeRange(0,styleSheetBody.length) withTemplate:@""];
			
			NSArray *classNameAndStyleStrings = [styleSheetBody componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"}"]];
			for( NSString *idStyleString in classNameAndStyleStrings )
			{
				if( [idStyleString length] > 1 ) //not necessary unless using shitty svgs
				{
					[self insertRule:idStyleString index:self.cssRules.length];
				}
				
			}
		}
	
    }
    return self;
}

@end
