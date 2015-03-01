#import "SDisposable.h"
#import "SEvent.h"

@interface SSubscriber : NSObject <SDisposable>
{
    @public
    void (^_next)(id);
    void (^_error)(id);
    void (^_completed)();
}

- (instancetype)initWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed;

- (void)_assignDisposable:(id<SDisposable>)disposable;
- (void)_markTerminatedWithoutDisposal;

- (void)putNext:(id)next;
- (void)putError:(id)error;
- (void)putCompletion;

@end
