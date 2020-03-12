#import <LegacyComponents/LegacyComponents.h>

@interface TGSecretTimerValueController : TGViewController

@property (nonatomic, copy) void (^timerValueSelected)(NSUInteger seconds);

@end
