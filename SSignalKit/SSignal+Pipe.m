#import "SSignal+Pipe.h"

#import "SBlockDisposable.h"
#import "SAtomic.h"
#import "SBag.h"

@implementation SPipe

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        SAtomic *subscribers = [[SAtomic alloc] initWithValue:[[SBag alloc] init]];
        
        _signalProducer = [^SSignal *
        {
            return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
            {
                __block NSUInteger index = 0;
                [subscribers with:^id(SBag *bag)
                {
                    index = [bag addItem:[^(id next)
                    {
                        [subscriber putNext:next];
                    } copy]];
                    return nil;
                }];
                
                return [[SBlockDisposable alloc] initWithBlock:^
                {
                    [subscribers with:^id(SBag *bag)
                    {
                        [bag removeItem:index];
                        return nil;
                    }];
                }];
            }];
        } copy];
        
        _sink = [^(id next)
        {
            NSArray *items = [subscribers with:^id(SBag *bag)
            {
                return [bag copyItems];
            }];
            for (void (^item)(id) in items)
            {
                item(next);
            }
        } copy];
    }
    return self;
}

@end
