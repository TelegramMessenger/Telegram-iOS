#import "SSignal.h"

@interface SSignal ()
{
}

@end

@implementation SSignal

- (instancetype)initWithGenerator:(id<SDisposable> (^)(SSubscriber *))generator
{
    self = [super init];
    if (self != nil)
    {
        _generator = [generator copy];
    }
    return self;
}

- (id<SDisposable>)startWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed
{
    SSubscriber *subscriber = [[SSubscriber alloc] initWithNext:next error:error completed:completed];
    return _generator(subscriber);
}

@end
