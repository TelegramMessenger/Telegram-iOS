#import "SSignal+Single.h"

@interface SSignal_Single : SSignal
{
    id _next;
}

@end

@implementation SSignal_Single

- (instancetype)initWithNext:(id)next
{
    self = [super init];
    if (self != nil)
    {
        _next = next;
    }
    return self;
}

- (id<SDisposable>)startWithNext:(void (^)(id))next error:(void (^)(id))__unused error completed:(void (^)())completed
{
    if (next)
        next(_next);
    if (completed)
        completed();
    return nil;
}

@end

@implementation SSignal (Single)

+ (SSignal *)single:(id)next
{
    return [[SSignal_Single alloc] initWithNext:next];
}

+ (SSignal *)fail:(id)error
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        SSubscriber_putError(subscriber, error);
    }];
}

+ (SSignal *)never
{
    return [[SSignal alloc] initWithGenerator:^(__unused SSubscriber *subscriber)
    {
    }];
}

+ (SSignal *)complete
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        SSubscriber_putCompletion(subscriber);
    }];
}

@end
