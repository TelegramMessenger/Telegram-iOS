#import "SSubscriber.h"

@interface SSignal : NSObject
{
@public
    void (^_generator)(SSubscriber *);
}

- (instancetype)initWithGenerator:(void (^)(SSubscriber *))generator;
- (id<SDisposable>)startWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed;

@end

inline id<SDisposable> SSignal_start(SSignal *signal, void (^next)(id), void (^error)(id), void (^completed)())
{
    SSubscriber *subscriber = [[SSubscriber alloc] initWithNext:next error:error completed:completed];
    signal->_generator(subscriber);
    return [subscriber _disposable];
}
