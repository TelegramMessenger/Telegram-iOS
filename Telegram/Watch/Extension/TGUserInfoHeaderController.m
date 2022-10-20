#import "TGUserInfoHeaderController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGDateUtils.h"
#import "TGStringUtils.h"

#import "WKInterfaceGroup+Signals.h"

#import "TGBridgeMediaSignals.h"

NSString *const TGUserInfoHeaderIdentifier = @"TGUserInfoHeader";

@interface TGUserInfoHeaderController ()
{
    NSString *_currentAvatarPhoto;
}
@end

@implementation TGUserInfoHeaderController

- (void)updateWithUser:(TGBridgeUser *)user context:(TGBridgeContext *)context
{
    self.nameLabel.text = user.displayName;

    if (user.photoSmall.length > 0)
    {
        self.avatarButton.enabled = true;
        self.avatarInitialsLabel.hidden = true;
        
        if (user.verified)
        {
            self.avatarGroup.backgroundColor = [UIColor clearColor];
            [self.avatarGroup setCornerRadius:0];
            self.avatarVerified.hidden = false;
        }
        else
        {
            self.avatarGroup.backgroundColor = [UIColor hexColor:0x1a1a1a];
            [self.avatarGroup setCornerRadius:22];
            self.avatarVerified.hidden = true;
        }
        
        if (![_currentAvatarPhoto isEqualToString:user.photoSmall])
        {
            _currentAvatarPhoto = user.photoSmall;
            
            __weak TGUserInfoHeaderController *weakSelf = self;
            [self.avatarGroup setBackgroundImageSignal:[[TGBridgeMediaSignals avatarWithPeerId:user.identifier url:_currentAvatarPhoto type:TGBridgeMediaAvatarTypeProfile] onError:^(id error)
            {
                __strong TGUserInfoHeaderController *strongSelf = weakSelf;
                if (strongSelf != nil)
                    strongSelf->_currentAvatarPhoto = nil;
            }] isVisible:self.isVisible];
        }
    }
    else
    {
        self.avatarButton.enabled = false;
        self.avatarInitialsLabel.hidden = false;
        self.avatarGroup.backgroundColor = [TGColor colorForUserId:user.identifier myUserId:context.userId];
        self.avatarInitialsLabel.text = [TGStringUtils initialsForFirstName:user.firstName lastName:user.lastName single:true];
        
        _currentAvatarPhoto = nil;
        [self.avatarGroup setBackgroundImageSignal:nil isVisible:self.isVisible];
    }
    
    if (user.identifier == 777000)
    {
        self.lastSeenLabel.textColor = [TGColor subtitleColor];
        self.lastSeenLabel.text = TGLocalized(@"Watch.UserInfo.Service");
    }
    else if (user.kind != TGBridgeUserKindGeneric)
    {
        self.lastSeenLabel.textColor = [TGColor subtitleColor];
        self.lastSeenLabel.text = TGLocalized(@"Bot.GenericBotStatus");
    }
    else if (user.online || user.identifier == context.userId)
    {
        self.lastSeenLabel.textColor = [TGColor accentColor];
        self.lastSeenLabel.text = TGLocalized(@"Presence.online");
    }
    else
    {
        self.lastSeenLabel.textColor = [TGColor subtitleColor];
        self.lastSeenLabel.text = [TGDateUtils stringForRelativeLastSeen:user.lastSeen];
    }
}

- (void)updateWithChannel:(TGBridgeChat *)channel
{
    self.nameLabel.text = channel.groupTitle;
    self.lastSeenLabel.textColor = [TGColor subtitleColor];
    
    if (!channel.isChannelGroup)
    {
        self.lastSeenLabel.text = TGLocalized(@"Channel.Status");
    }
    else
    {
        if (channel.participantsCount == 0)
        {
            self.lastSeenLabel.text = @"";
        }
        else
        {
            self.lastSeenLabel.text = [NSString stringWithFormat:TGLocalized([TGStringUtils integerValueFormat:@"Conversation.StatusMembers_" value:channel.participantsCount]), [NSString stringWithFormat:@"%d", (int32_t)channel.participantsCount]];
        }
    }
    
    if (channel.groupPhotoSmall.length > 0)
    {
        self.avatarButton.enabled = true;
        self.avatarInitialsLabel.hidden = true;
        
        if (channel.verified)
        {
            self.avatarGroup.backgroundColor = [UIColor clearColor];
            [self.avatarGroup setCornerRadius:0];
            self.avatarVerified.hidden = false;
        }
        else
        {
            self.avatarGroup.backgroundColor = [UIColor hexColor:0x1a1a1a];
            [self.avatarGroup setCornerRadius:22];
            self.avatarVerified.hidden = true;
        }
        
        if (![_currentAvatarPhoto isEqualToString:channel.groupPhotoSmall])
        {
            _currentAvatarPhoto = channel.groupPhotoSmall;
            
            __weak TGUserInfoHeaderController *weakSelf = self;
            [self.avatarGroup setBackgroundImageSignal:[[TGBridgeMediaSignals avatarWithPeerId:channel.identifier url:_currentAvatarPhoto type:TGBridgeMediaAvatarTypeProfile] onError:^(id error)
            {
                __strong TGUserInfoHeaderController *strongSelf = weakSelf;
                if (strongSelf != nil)
                    strongSelf->_currentAvatarPhoto = nil;
            }] isVisible:self.isVisible];
        }
    }
    else
    {
        self.avatarButton.enabled = false;
        self.avatarInitialsLabel.hidden = false;
        self.avatarGroup.backgroundColor = [TGColor colorForGroupId:channel.identifier];
        [self.avatarGroup setCornerRadius:22];
        self.avatarVerified.hidden = true;
        self.avatarInitialsLabel.text = [TGStringUtils initialForGroupName:channel.groupTitle];
        
        _currentAvatarPhoto = nil;
        [self.avatarGroup setBackgroundImageSignal:nil isVisible:self.isVisible];
    }
}

- (void)avatarPressedAction
{
    if (self.avatarPressed != nil)
        self.avatarPressed();
}

- (void)notifyVisiblityChange
{
    [self.avatarGroup updateIfNeeded];
}

#pragma mark -

+ (NSString *)identifier
{
    return TGUserInfoHeaderIdentifier;
}

@end
