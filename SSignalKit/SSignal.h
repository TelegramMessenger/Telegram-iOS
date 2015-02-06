#import "SSubscriber.h"

@interface SSignal : NSObject
{
@public
    id<SDisposable> (^_generator)(SSubscriber *);
}

- (instancetype)initWithGenerator:(id<SDisposable> (^)(SSubscriber *))generator;
- (id<SDisposable>)startWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed;

@end

