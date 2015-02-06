#import "SSignal+Mapping.h"

@implementation SSignal (Mapping)

- (SSignal *)map:(id (^)(id))f
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            SSubscriber_putNext(subscriber, f(next));
        } error:^(id error)
        {
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            SSubscriber_putCompletion(subscriber);
        }];
    }];
}

- (SSignal *)_mapInplace:(id (^)(id))f
{
    id<SDisposable> (^generator)(SSubscriber *) = self->_generator;
    self->_generator = [^id<SDisposable> (SSubscriber *subscriber)
    {
        SSubscriber *mappedSubscriber = [[SSubscriber alloc] initWithNext:^(id next)
        {
            subscriber->_next(f(next));
        } error:subscriber->_error completed:subscriber->_completed];
        
        return generator(mappedSubscriber);
    } copy];
    
    return self;
}

- (SSignal *)filter:(bool (^)(id))f
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            if (f(next))
                SSubscriber_putNext(subscriber, next);
        } error:^(id error)
        {
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            SSubscriber_putCompletion(subscriber);
        }];
    }];
}

@end
