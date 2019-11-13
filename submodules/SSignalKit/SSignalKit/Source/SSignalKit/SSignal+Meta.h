#import <SSignalKit/SSignal.h>

@class SQueue;

@interface SSignal (Meta)

- (SSignal *)switchToLatest;
- (SSignal *)mapToSignal:(SSignal *(^)(id))f;
- (SSignal *)mapToQueue:(SSignal *(^)(id))f;
- (SSignal *)mapToThrottled:(SSignal *(^)(id))f;
- (SSignal *)then:(SSignal *)signal;
- (SSignal *)queue;
- (SSignal *)throttled;
+ (SSignal *)defer:(SSignal *(^)())generator;

@end

@interface SSignalQueue : NSObject

- (SSignal *)enqueue:(SSignal *)signal;

@end
