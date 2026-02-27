#import "TGWatchColor.h"
#import <WatchCommonWatch/WatchCommonWatch.h>
#import <CommonCrypto/CommonDigest.h>

@implementation UIColor (TGColor)

+ (UIColor *)hexColor:(NSInteger)hex
{
    return [[UIColor alloc] initWithRed:(((hex >> 16) & 0xff) / 255.0f) green:(((hex >> 8) & 0xff) / 255.0f) blue:(((hex) & 0xff) / 255.0f) alpha:1.0f];
}

+ (UIColor *)hexColor:(NSInteger)hex withAlpha:(CGFloat)alpha
{
    return [[UIColor alloc] initWithRed:(((hex >> 16) & 0xff) / 255.0f) green:(((hex >> 8) & 0xff) / 255.0f) blue:(((hex) & 0xff) / 255.0f) alpha:alpha];
}

@end

@implementation TGColor

+ (NSArray *)placeholderColors
{
    static NSArray *colors;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        colors = @[ [UIColor hexColor:0xff516a],
                    [UIColor hexColor:0xffa85c],
                    [UIColor hexColor:0x665fff],
                    [UIColor hexColor:0x54cb68],
                    [UIColor hexColor:0x28c9b7],
                    [UIColor hexColor:0x2a9ef1],
                    [UIColor hexColor:0xd669ed]];
    });
    
    return colors;
}

+ (UIColor *)colorForUserId:(int32_t)userId myUserId:(int32_t)myUserId
{
    return [self placeholderColors][abs(userId) % 7];
}

+ (UIColor *)colorForGroupId:(int64_t)groupId
{
    int32_t peerId = 0;
    if (TGPeerIdIsGroup(groupId)) {
        peerId = TGGroupIdFromPeerId(groupId);
    } else if (TGPeerIdIsChannel(groupId)) {
        peerId = TGChannelIdFromPeerId(groupId);
    }
    return [self placeholderColors][peerId % 7];
}

+ (UIColor *)accentColor
{
    return [UIColor hexColor:0x2ea4e5];
}

+ (UIColor *)subtitleColor
{
    return [UIColor hexColor:0x8f8f8f];
}

@end
