#import <SSignalKit/SSignal.h>

@interface SSignal (Single)

+ (SSignal * _Nonnull)single:(id _Nullable)next;
+ (SSignal * _Nonnull)fail:(id _Nullable)error;
+ (SSignal * _Nonnull)never;
+ (SSignal * _Nonnull)complete;

@end
