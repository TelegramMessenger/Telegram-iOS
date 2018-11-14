#import "TGBridgeMessageEntities.h"

#import <LegacyComponents/LegacyComponents.h>

@interface TGBridgeMessageEntity (TGMessageEntity)

+ (TGBridgeMessageEntity *)entityWithTGMessageEntity:(TGMessageEntity *)entity;

@end
