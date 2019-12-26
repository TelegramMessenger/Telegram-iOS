#import "SVGElementInstanceList.h"
#import "SVGElementInstanceList_Internal.h"

@implementation SVGElementInstanceList
@synthesize internalArray;


- (id)init
{
    self = [super init];
    if (self) {
        self.internalArray = [NSMutableArray array];
    }
    return self;
}

-(unsigned long)length
{
	return [self.internalArray count];
}

-(SVGElementInstance*) item:(unsigned long) index
{
	if( index >= [self.internalArray count] )
		return nil;
	
	return [self.internalArray objectAtIndex:index];
}

@end
