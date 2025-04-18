#import <WatchCommon/TGBridgeCommon.h>
#import <WatchCommon/TGBridgeMessage.h>

@interface TGBridgeChat : NSObject <NSCoding>

@property (nonatomic) int64_t identifier;
@property (nonatomic) NSTimeInterval date;
@property (nonatomic) int32_t fromUid;
@property (nonatomic, strong) NSString *text;

@property (nonatomic, strong) NSArray *media;

@property (nonatomic) bool outgoing;
@property (nonatomic) bool unread;
@property (nonatomic) bool deliveryError;
@property (nonatomic) TGBridgeMessageDeliveryState deliveryState;

@property (nonatomic) int32_t unreadCount;

@property (nonatomic) bool isBroadcast;

@property (nonatomic, strong) NSString *groupTitle;
@property (nonatomic, strong) NSString *groupPhotoSmall;
@property (nonatomic, strong) NSString *groupPhotoBig;

@property (nonatomic) bool isGroup;
@property (nonatomic) bool hasLeftGroup;
@property (nonatomic) bool isKickedFromGroup;

@property (nonatomic) bool isChannel;
@property (nonatomic) bool isChannelGroup;

@property (nonatomic, strong) NSString *userName;
@property (nonatomic, strong) NSString *about;
@property (nonatomic) bool verified;

@property (nonatomic) int32_t participantsCount;
@property (nonatomic, strong) NSArray *participants;

- (NSArray<NSNumber *> *)involvedUserIds;
- (NSArray<NSNumber *> *)participantsUserIds;

@end

extern NSString *const TGBridgeChatKey;
extern NSString *const TGBridgeChatsArrayKey;
