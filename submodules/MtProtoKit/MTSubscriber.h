#import <Foundation/Foundation.h>

#import "MTDisposable.h"

@interface MTSubscriber : NSObject <MTDisposable>
{
}

- (instancetype)initWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed;

- (void)_assignDisposable:(id<MTDisposable>)disposable;
- (void)_markTerminatedWithoutDisposal;

- (void)putNext:(id)next;
- (void)putError:(id)error;
- (void)putCompletion;

@end
