#import "SDisposable.h"
#import "SEvent.h"

@interface SSubscriber : NSObject
{
    @public
    void (^_next)(id);
    void (^_error)(id);
    void (^_completed)();
}

- (instancetype)initWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed;

- (void)_assignDisposable:(id<SDisposable>)disposable;

- (void)putEvent:(SEvent *)event;
- (void)putNext:(id)next;
- (void)putError:(id)error;
- (void)putCompletion;

@end

#ifdef __cplusplus
extern "C" {
#endif
    
void SSubscriber_putNext(SSubscriber *subscriber, id next);
void SSubscriber_putError(SSubscriber *subscriber, id error);
void SSubscriber_putCompletion(SSubscriber *subscriber);
void SSubscriber_putEvent(SSubscriber *subscriber, SEvent *event);

#ifdef __cplusplus
}
#endif