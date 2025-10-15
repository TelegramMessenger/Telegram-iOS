#import "TGBridgePeerNotificationSettings.h"

NSString *const TGBridgePeerNotificationSettingsMuteForKey = @"muteFor";

@implementation TGBridgePeerNotificationSettings

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _muteFor = [aDecoder decodeInt32ForKey:TGBridgePeerNotificationSettingsMuteForKey];
    }
    return self;
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder
{
    [aCoder encodeInt32:self.muteFor forKey:TGBridgePeerNotificationSettingsMuteForKey];
}

@end
