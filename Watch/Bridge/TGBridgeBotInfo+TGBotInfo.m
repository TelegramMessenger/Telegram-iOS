#import "TGBridgeBotInfo+TGBotInfo.h"

#import <LegacyComponents/LegacyComponents.h>

#import "TGBridgeBotCommandInfo+TGBotCommandInfo.h"

@implementation TGBridgeBotInfo (TGBotInfo)

+ (TGBridgeBotInfo *)botInfoWithTGBotInfo:(TGBotInfo *)botInfo userId:(int32_t)userId
{
    TGBridgeBotInfo *bridgeBotInfo = [[TGBridgeBotInfo alloc] init];
    bridgeBotInfo->_version = botInfo.version;
    bridgeBotInfo->_userId = userId;
    bridgeBotInfo->_shortDescription = botInfo.shortDescription;
    bridgeBotInfo->_botDescription = botInfo.botDescription;
    
    NSMutableArray *commandList = [[NSMutableArray alloc] init];
    for (TGBotComandInfo *commandInfo in botInfo.commandList)
    {
        TGBridgeBotCommandInfo *bridgeCommandInfo = [TGBridgeBotCommandInfo botCommandInfoWithTGBotCommandInfo:commandInfo];
        if (bridgeCommandInfo != nil)
            [commandList addObject:bridgeCommandInfo];
    }
    bridgeBotInfo->_commandList = commandList;
    
    return bridgeBotInfo;
}

@end
