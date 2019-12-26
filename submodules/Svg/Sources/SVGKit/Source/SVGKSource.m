#import "SVGKSource.h"


@implementation SVGKSource

@synthesize svgLanguageVersion;
@synthesize stream;

- (id)initWithInputSteam:(NSInputStream*)s {
	self = [super init];
	if (!self)
		return nil;
	
	self.stream = s;
	return self;
}

- (id) initForCopying
{
	self = [super init];
	if( !self )
		return nil;
	
	return self;
}

- (SVGKSource *)sourceFromRelativePath:(NSString *)path {
    return nil;
}

-(id)copyWithZone:(NSZone *)zone
{
	id copy = [[[self class] allocWithZone:zone] initForCopying];
	
	if( copy )
	{	
		[copy setApproximateLengthInBytesOr0:self.approximateLengthInBytesOr0];
	}
	
	return copy;
}

-(NSString *)keyForAppleDictionaries
{
	NSAssert(false, @"Subclasses MUST implement this property/method in their own way and stick to Apple's rules for Keys in NSDictionary");
	return nil;
}


@end
