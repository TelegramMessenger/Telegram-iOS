#import "TGBridgeMessageEntity+TGMessageEntity.h"

#import <LegacyComponents/LegacyComponents.h>

@implementation TGBridgeMessageEntity (TGMessageEntity)

+ (TGBridgeMessageEntity *)entityWithTGMessageEntity:(TGMessageEntity *)entity
{
    Class bridgeEntityClass = nil;
    
    if ([entity isKindOfClass:[TGMessageEntityUrl class]])
        bridgeEntityClass = [TGBridgeMessageEntityUrl class];
    else if ([entity isKindOfClass:[TGMessageEntityEmail class]])
        bridgeEntityClass = [TGBridgeMessageEntityEmail class];
    else if ([entity isKindOfClass:[TGMessageEntityTextUrl class]])
        bridgeEntityClass = [TGBridgeMessageEntityTextUrl class];
    else if ([entity isKindOfClass:[TGMessageEntityMention class]])
        bridgeEntityClass = [TGBridgeMessageEntityMention class];
    else if ([entity isKindOfClass:[TGMessageEntityHashtag class]])
        bridgeEntityClass = [TGBridgeMessageEntityHashtag class];
    else if ([entity isKindOfClass:[TGMessageEntityBotCommand class]])
        bridgeEntityClass = [TGBridgeMessageEntityBotCommand class];
    else if ([entity isKindOfClass:[TGMessageEntityBold class]])
        bridgeEntityClass = [TGBridgeMessageEntityBold class];
    else if ([entity isKindOfClass:[TGMessageEntityItalic class]])
        bridgeEntityClass = [TGBridgeMessageEntityItalic class];
    else if ([entity isKindOfClass:[TGMessageEntityCode class]])
        bridgeEntityClass = [TGBridgeMessageEntityCode class];
    else if ([entity isKindOfClass:[TGMessageEntityPre class]])
        bridgeEntityClass = [TGBridgeMessageEntityPre class];
    
    if (bridgeEntityClass != nil)
        return [bridgeEntityClass entitityWithRange:entity.range];
    
    return nil;
}

@end
