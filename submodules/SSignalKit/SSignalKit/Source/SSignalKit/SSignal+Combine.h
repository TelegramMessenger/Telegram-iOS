#import <SSignalKit/SSignal.h>

@interface SSignal (Combine)

+ (SSignal * _Nonnull)combineSignals:(NSArray * _Nonnull)signals;
+ (SSignal * _Nonnull)combineSignals:(NSArray * _Nonnull)signals withInitialStates:(NSArray * _Nullable)initialStates;

+ (SSignal * _Nonnull)mergeSignals:(NSArray * _Nonnull)signals;

@end
