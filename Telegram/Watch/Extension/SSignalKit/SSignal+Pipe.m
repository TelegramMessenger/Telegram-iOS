#import "SSignal+Pipe.h"

#import "SBlockDisposable.h"
#import "SAtomic.h"
#import "SBag.h"

@interface SPipeReplayState : NSObject

@property (nonatomic, readonly) bool hasReceivedValue;
@property (nonatomic, strong, readonly) id recentValue;

@end

@implementation SPipeReplayState

- (instancetype)initWithReceivedValue:(bool)receivedValue recentValue:(id)recentValue
{
    self = [super init];
    if (self != nil)
    {
        _hasReceivedValue = receivedValue;
        _recentValue = recentValue;
    }
    return self;
}

@end

@implementation SPipe

- (instancetype)init
{
    return [self initWithReplay:false];
}

- (instancetype)initWithReplay:(bool)replay
{
    self = [super init];
    if (self != nil)
    {
        SAtomic *subscribers = [[SAtomic alloc] initWithValue:[[SBag alloc] init]];
        SAtomic *replayState = replay ? [[SAtomic alloc] initWithValue:[[SPipeReplayState alloc] initWithReceivedValue:false recentValue:nil]] : nil;
        
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
                
                if (replay)
                {
                    [replayState with:^id(SPipeReplayState *state)
                    {
                        if (state.hasReceivedValue)
                            [subscriber putNext:state.recentValue];
                        return nil;
                    }];
                }
                
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
            
            if (replay)
            {
                [replayState modify:^id(__unused SPipeReplayState *state)
                {
                    return [[SPipeReplayState alloc] initWithReceivedValue:true recentValue:next];
                }];
            }
        } copy];
    }
    return self;
}

@end
