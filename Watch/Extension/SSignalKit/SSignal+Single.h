#import <SSignalKit/SSignal.h>

@interface SSignal (Single)

+ (SSignal *)single:(id)next;
+ (SSignal *)fail:(id)error;
+ (SSignal *)never;
+ (SSignal *)complete;

@end
