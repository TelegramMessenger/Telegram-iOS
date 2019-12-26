#import "StyleSheetList.h"
#import "StyleSheetList+Mutable.h"

@implementation StyleSheetList

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
	return self.internalArray.count;
}

-(StyleSheet*) item:(unsigned long) index
{
	return [self.internalArray objectAtIndex:index];
}

@end
