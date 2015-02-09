#import "SSignal+Mapping.h"

@implementation SSignal (Mapping)

- (SSignal *)map:(id (^)(id))f
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            [subscriber putNext:f(next)];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }];
    }];
}

- (SSignal *)_mapInplace:(id (^)(id))f
{
    id<SDisposable> (^generator)(SSubscriber *) = self->_generator;
    self->_generator = [^id<SDisposable> (SSubscriber *subscriber)
    {
        void (^next)(id) = subscriber->_next;
        subscriber->_next = ^(id value)
        {
            next(f(value));
        };
        
        return generator(subscriber);
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
                [subscriber putNext:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }];
    }];
}

@end
