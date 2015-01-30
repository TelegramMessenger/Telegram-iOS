#import "SSignal.h"

@interface SMulticastSignalManager : NSObject

- (SSignal *)multicastedSignalForKey:(NSString *)key producer:(SSignal *(^)())producer;

@end
