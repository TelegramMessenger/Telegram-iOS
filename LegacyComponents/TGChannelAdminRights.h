#import <Foundation/Foundation.h>

#import <LegacyComponents/PSCoding.h>

@class TLChannelAdminRights;

@interface TGChannelAdminRights : NSObject <PSCoding>

@property (nonatomic, readonly) bool canChangeInfo;
@property (nonatomic, readonly) bool canPostMessages;
@property (nonatomic, readonly) bool canEditMessages;
@property (nonatomic, readonly) bool canDeleteMessages;
@property (nonatomic, readonly) bool canBanUsers;
@property (nonatomic, readonly) bool canInviteUsers;
@property (nonatomic, readonly) bool canChangeInviteLink;
@property (nonatomic, readonly) bool canPinMessages;
@property (nonatomic, readonly) bool canAddAdmins;

- (instancetype)initWithCanChangeInfo:(bool)canChangeInfo canPostMessages:(bool)canPostMessages canEditMessages:(bool)canEditMessages canDeleteMessages:(bool)canDeleteMessages canBanUsers:(bool)canBanUsers canInviteUsers:(bool)canInviteUsers canChangeInviteLink:(bool)canChangeInviteLink canPinMessages:(bool)canPinMessages canAddAdmins:(bool)canAddAdmins;

- (instancetype)initWithFlags:(int32_t)flags;

- (int32_t)tlFlags;
- (bool)hasAnyRights;
- (int32_t)numberOfRights;

@end
