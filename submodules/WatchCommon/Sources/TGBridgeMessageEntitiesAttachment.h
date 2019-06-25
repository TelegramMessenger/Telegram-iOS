#if TARGET_OS_WATCH
#import <WatchCommonWatch/TGBridgeMediaAttachment.h>
#import <WatchCommonWatch/TGBridgeMessageEntities.h>
#else
#import <WatchCommon/TGBridgeMediaAttachment.h>
#import <WatchCommon/TGBridgeMessageEntities.h>
#endif

@interface TGBridgeMessageEntitiesAttachment : TGBridgeMediaAttachment

@property (nonatomic, strong) NSArray *entities;

@end
