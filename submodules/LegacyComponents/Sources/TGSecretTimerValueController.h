#import <LegacyComponents/TGViewController.h>

@interface TGSecretTimerValueController : TGViewController

@property (nonatomic, copy) void (^timerValueSelected)(NSUInteger seconds);

@end
