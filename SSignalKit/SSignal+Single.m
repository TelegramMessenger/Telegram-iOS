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
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SSubscriber_putError(subscriber, error);
        return nil;
    }];
}

+ (SSignal *)never
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (__unused SSubscriber *subscriber)
    {
        return nil;
    }];
}

+ (SSignal *)complete
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SSubscriber_putCompletion(subscriber);
        return nil;
    }];
}

@end
