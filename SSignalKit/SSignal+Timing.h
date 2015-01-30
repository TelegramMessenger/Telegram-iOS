#import "SSignal.h"

#import "SQueue.h"

@interface SSignal (Timing)

- (SSignal *)delay:(NSTimeInterval)seconds onQueue:(SQueue *)queue;

@end
