#import "TGBridgeChat.h"
#import "TGBridgePeerIdAdapter.h"

NSString *const TGBridgeChatIdentifierKey = @"identifier";
NSString *const TGBridgeChatDateKey = @"date";
NSString *const TGBridgeChatFromUidKey = @"fromUid";
NSString *const TGBridgeChatTextKey = @"text";
NSString *const TGBridgeChatOutgoingKey = @"outgoing";
NSString *const TGBridgeChatUnreadKey = @"unread";
NSString *const TGBridgeChatMediaKey = @"media";
NSString *const TGBridgeChatUnreadCountKey = @"unreadCount";
NSString *const TGBridgeChatGroupTitleKey = @"groupTitle";
NSString *const TGBridgeChatGroupPhotoSmallKey = @"groupPhotoSmall";
NSString *const TGBridgeChatGroupPhotoBigKey = @"groupPhotoBig";
NSString *const TGBridgeChatIsGroupKey = @"isGroup";
NSString *const TGBridgeChatHasLeftGroupKey = @"hasLeftGroup";
NSString *const TGBridgeChatIsKickedFromGroupKey = @"isKickedFromGroup";
NSString *const TGBridgeChatIsChannelKey = @"isChannel";
NSString *const TGBridgeChatIsChannelGroupKey = @"isChannelGroup";
NSString *const TGBridgeChatUserNameKey = @"userName";
NSString *const TGBridgeChatAboutKey = @"about";
NSString *const TGBridgeChatVerifiedKey = @"verified";
NSString *const TGBridgeChatGroupParticipantsCountKey = @"participantsCount";
NSString *const TGBridgeChatGroupParticipantsKey = @"participants";
NSString *const TGBridgeChatDeliveryStateKey = @"deliveryState";
NSString *const TGBridgeChatDeliveryErrorKey = @"deliveryError";

NSString *const TGBridgeChatKey = @"chat";
NSString *const TGBridgeChatsArrayKey = @"chats";

@implementation TGBridgeChat

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _identifier = [aDecoder decodeInt64ForKey:TGBridgeChatIdentifierKey];
        _date = [aDecoder decodeDoubleForKey:TGBridgeChatDateKey];
        _fromUid = [aDecoder decodeInt32ForKey:TGBridgeChatFromUidKey];
        _text = [aDecoder decodeObjectForKey:TGBridgeChatTextKey];
        _outgoing = [aDecoder decodeBoolForKey:TGBridgeChatOutgoingKey];
        _unread = [aDecoder decodeBoolForKey:TGBridgeChatUnreadKey];
        _unreadCount = [aDecoder decodeInt32ForKey:TGBridgeChatUnreadCountKey];
        _deliveryState = [aDecoder decodeInt32ForKey:TGBridgeChatDeliveryStateKey];
        _deliveryError = [aDecoder decodeBoolForKey:TGBridgeChatDeliveryErrorKey];
        _media = [aDecoder decodeObjectForKey:TGBridgeChatMediaKey];
        
        _groupTitle = [aDecoder decodeObjectForKey:TGBridgeChatGroupTitleKey];
        _groupPhotoSmall = [aDecoder decodeObjectForKey:TGBridgeChatGroupPhotoSmallKey];
        _groupPhotoBig = [aDecoder decodeObjectForKey:TGBridgeChatGroupPhotoBigKey];
        _isGroup = [aDecoder decodeBoolForKey:TGBridgeChatIsGroupKey];
        _hasLeftGroup = [aDecoder decodeBoolForKey:TGBridgeChatHasLeftGroupKey];
        _isKickedFromGroup = [aDecoder decodeBoolForKey:TGBridgeChatIsKickedFromGroupKey];
        _isChannel = [aDecoder decodeBoolForKey:TGBridgeChatIsChannelKey];
        _isChannelGroup = [aDecoder decodeBoolForKey:TGBridgeChatIsChannelGroupKey];
        _userName = [aDecoder decodeObjectForKey:TGBridgeChatUserNameKey];
        _about = [aDecoder decodeObjectForKey:TGBridgeChatAboutKey];
        _verified = [aDecoder decodeBoolForKey:TGBridgeChatVerifiedKey];
        _participantsCount = [aDecoder decodeInt32ForKey:TGBridgeChatGroupParticipantsCountKey];
        _participants = [aDecoder decodeObjectForKey:TGBridgeChatGroupParticipantsKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.identifier forKey:TGBridgeChatIdentifierKey];
    [aCoder encodeDouble:self.date forKey:TGBridgeChatDateKey];
    [aCoder encodeInt32:self.fromUid forKey:TGBridgeChatFromUidKey];
    [aCoder encodeObject:self.text forKey:TGBridgeChatTextKey];
    [aCoder encodeBool:self.outgoing forKey:TGBridgeChatOutgoingKey];
    [aCoder encodeBool:self.unread forKey:TGBridgeChatUnreadKey];
    [aCoder encodeInt32:self.unreadCount forKey:TGBridgeChatUnreadCountKey];
    [aCoder encodeInt32:self.deliveryState forKey:TGBridgeChatDeliveryStateKey];
    [aCoder encodeBool:self.deliveryError forKey:TGBridgeChatDeliveryErrorKey];
    [aCoder encodeObject:self.media forKey:TGBridgeChatMediaKey];
    
    [aCoder encodeObject:self.groupTitle forKey:TGBridgeChatGroupTitleKey];
    [aCoder encodeObject:self.groupPhotoSmall forKey:TGBridgeChatGroupPhotoSmallKey];
    [aCoder encodeObject:self.groupPhotoBig forKey:TGBridgeChatGroupPhotoBigKey];
    
    [aCoder encodeBool:self.isGroup forKey:TGBridgeChatIsGroupKey];
    [aCoder encodeBool:self.hasLeftGroup forKey:TGBridgeChatHasLeftGroupKey];
    [aCoder encodeBool:self.isKickedFromGroup forKey:TGBridgeChatIsKickedFromGroupKey];
    
    [aCoder encodeBool:self.isChannel forKey:TGBridgeChatIsChannelKey];
    [aCoder encodeBool:self.isChannelGroup forKey:TGBridgeChatIsChannelGroupKey];
    [aCoder encodeObject:self.userName forKey:TGBridgeChatUserNameKey];
    [aCoder encodeObject:self.about forKey:TGBridgeChatAboutKey];
    [aCoder encodeBool:self.verified forKey:TGBridgeChatVerifiedKey];
    
    [aCoder encodeInt32:self.participantsCount forKey:TGBridgeChatGroupParticipantsCountKey];
    [aCoder encodeObject:self.participants forKey:TGBridgeChatGroupParticipantsKey];
}

- (NSArray<NSNumber *> *)involvedUserIds
{
    NSMutableSet<NSNumber *> *userIds = [[NSMutableSet alloc] init];
    if (!self.isGroup && !self.isChannel && self.identifier != 0)
        [userIds addObject:[NSNumber numberWithLongLong:self.identifier]];
    if ((!self.isChannel || self.isChannelGroup) && self.fromUid != self.identifier && self.fromUid != 0 && !TGPeerIdIsChannel(self.fromUid) && self.fromUid > 0)
        [userIds addObject:[NSNumber numberWithLongLong:self.fromUid]];
    
    for (TGBridgeMediaAttachment *attachment in self.media)
    {
        if ([attachment isKindOfClass:[TGBridgeActionMediaAttachment class]])
        {
            TGBridgeActionMediaAttachment *actionAttachment = (TGBridgeActionMediaAttachment *)attachment;
            if (actionAttachment.actionData[@"uid"] != nil)
                [userIds addObject:[NSNumber numberWithLongLong:[actionAttachment.actionData[@"uid"] longLongValue]]];
        }
    }
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (NSNumber *object in userIds) {
        [result addObject:object];
    }
    return result;
}

- (NSArray<NSNumber *> *)participantsUserIds
{
    NSMutableSet<NSNumber *> *userIds = [[NSMutableSet alloc] init];
    
    for (NSNumber *uid in self.participants) {
        [userIds addObject:[NSNumber numberWithLongLong:uid.longLongValue]];
    }
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (NSNumber *object in userIds) {
        [result addObject:object];
    }
    return result;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    return self.identifier == ((TGBridgeChat *)object).identifier;
}

@end
