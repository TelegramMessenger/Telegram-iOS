#import "TGBridgeBotInfo.h"

@class TGBotInfo;

@interface TGBridgeBotInfo (TGBotInfo)

+ (TGBridgeBotInfo *)botInfoWithTGBotInfo:(TGBotInfo *)botInfo userId:(int32_t)userId;

@end
