#import "NSWeakReference.h"

@implementation NSWeakReference

- (instancetype)initWithValue:(id)value {
    self = [super init];
    if (self != nil) {
        self.value = value;
    }
    return self;
}

@end
