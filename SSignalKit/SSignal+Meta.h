#import <SSignalKit/SSignal.h>

@class SQueue;

@interface SSignal (Meta)

- (SSignal *)switchToLatest;
- (SSignal *)mapToSignal:(SSignal *(^)(id))f;
- (SSignal *)mapToQueue:(SSignal *(^)(id))f;
- (SSignal *)then:(SSignal *)signal;
- (SSignal *)queue;

@end
