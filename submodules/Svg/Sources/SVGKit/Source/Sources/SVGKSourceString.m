#import "SVGKSourceString.h"

@implementation SVGKSourceString

-(NSString *)keyForAppleDictionaries
{
	return self.rawString;
}

+ (SVGKSource*)sourceFromContentsOfString:(NSString*)rawString {
	NSInputStream* stream = [NSInputStream inputStreamWithData:[rawString dataUsingEncoding:NSUTF8StringEncoding]];
	//DO NOT DO THIS: let the parser do it at last possible moment (Apple has threading problems otherwise!) [stream open];
	
	SVGKSource* s = [[SVGKSourceString alloc] initWithInputSteam:stream];
	s.approximateLengthInBytesOr0 = [rawString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	
	return s;
}

-(id)copyWithZone:(NSZone *)zone
{
	id copy = [super copyWithZone:zone];
	
	if( copy )
	{	
		/** clone bits */
		[copy setRawString:[self.rawString copy]];
		
		/** Finally, manually intialize the input stream, as required by super class */
		[copy setStream:[NSInputStream inputStreamWithData:[((SVGKSourceString*)copy).rawString dataUsingEncoding:NSUTF8StringEncoding]]];
	}
	
	return copy;
}

@end
