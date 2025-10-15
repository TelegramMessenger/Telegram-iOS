#import "TGAudioMicAlertController.h"
#import "TGWatchCommon.h"

NSString *const TGAudioMicAlertControllerIdentifier = @"TGAudioMicAlertController";

@implementation TGAudioMicAlertController

- (void)configureWithContext:(id<TGInterfaceContext>)context
{
    self.alertLabel.text = TGLocalized(@"Watch.Microphone.Access");
}

+ (NSString *)identifier
{
    return TGAudioMicAlertControllerIdentifier;
}

@end
