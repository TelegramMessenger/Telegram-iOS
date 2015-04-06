#import "SSignal.h"

#import "SQueue.h"

@interface SSignal (Timing)

- (SSignal *)delay:(NSTimeInterval)seconds onQueue:(SQueue *)queue;
- (SSignal *)timeout:(NSTimeInterval)seconds onQueue:(SQueue *)queue or:(SSignal *)signal;

@end
