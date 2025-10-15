#import "SSignal+Mapping.h"

#import "SAtomic.h"

@interface SSignalIgnoreRepeatedState: NSObject

@property (nonatomic, strong) id value;
@property (nonatomic) bool hasValue;

@end

@implementation SSignalIgnoreRepeatedState

@end

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

- (SSignal *)ignoreRepeated {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        SAtomic *state = [[SAtomic alloc] initWithValue:[[SSignalIgnoreRepeatedState alloc] init]];
        
        return [self startWithNext:^(id next) {
            bool shouldPassthrough = [[state with:^id(SSignalIgnoreRepeatedState *state) {
                if (!state.hasValue) {
                    state.hasValue = true;
                    state.value = next;
                    return @true;
                } else if ((state.value == nil && next == nil) || [(id<NSObject>)state.value isEqual:next]) {
                    return @false;
                }
                state.value = next;
                return @true;
            }] boolValue];
            
            if (shouldPassthrough) {
                [subscriber putNext:next];
            }
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
