#import "TGUserRowController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGDateUtils.h"
#import "TGStringUtils.h"

#import "WKInterfaceGroup+Signals.h"

#import "TGBridgeMediaSignals.h"

NSString *const TGUserRowIdentifier = @"TGUserRow";

@interface TGUserRowController ()
{
    NSString *_currentAvatarPhoto;
}
@end

@implementation TGUserRowController

- (void)updateWithUser:(TGBridgeUser *)user context:(TGBridgeContext *)context
{
    self.nameLabel.text = user.displayName;
    
    [self updateAvatarWithUser:user context:context];
    
    if (user.kind != TGBridgeUserKindGeneric)
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

- (void)updateWithChannel:(TGBridgeChat *)channel context:(TGBridgeContext *)context
{
    self.nameLabel.text = channel.groupTitle;
    [self updateAvatarWithChat:channel context:context];
}

- (void)updateWithBotCommandInfo:(TGBridgeBotCommandInfo *)commandInfo botUser:(TGBridgeUser *)botUser context:(TGBridgeContext *)context
{
    self.nameLabel.text = [NSString stringWithFormat:@"/%@", commandInfo.command];
    self.lastSeenLabel.textColor = [TGColor subtitleColor];
    self.lastSeenLabel.text = commandInfo.commandDescription.length > 0 ? commandInfo.commandDescription : nil;
    [self updateAvatarWithUser:botUser context:context];
}

- (void)updateAvatarWithUser:(TGBridgeUser *)user context:(TGBridgeContext *)context
{
    if (user.photoSmall.length > 0)
    {
        self.avatarInitialsLabel.hidden = true;
        self.avatarGroup.backgroundColor = [UIColor hexColor:0x222223];
        if (![_currentAvatarPhoto isEqualToString:user.photoSmall])
        {
            _currentAvatarPhoto = user.photoSmall;
            
            __weak TGUserRowController *weakSelf = self;
            [self.avatarGroup setBackgroundImageSignal:[[TGBridgeMediaSignals avatarWithPeerId:user.identifier url:_currentAvatarPhoto type:TGBridgeMediaAvatarTypeSmall] onNext:^(id next)
            {
                __strong TGUserRowController *strongSelf = weakSelf;
                if (strongSelf != nil)
                    strongSelf->_currentAvatarPhoto = nil;
            }] isVisible:self.isVisible];
        }
    }
    else
    {
        self.avatarInitialsLabel.hidden = false;
        self.avatarGroup.backgroundColor = [TGColor colorForUserId:user.identifier myUserId:context.userId];
        self.avatarInitialsLabel.text = [TGStringUtils initialsForFirstName:user.firstName lastName:user.lastName single:true];
        
        [self.avatarGroup setBackgroundImageSignal:nil isVisible:self.isVisible];
        _currentAvatarPhoto = nil;
    }
}

- (void)updateAvatarWithChat:(TGBridgeChat *)chat context:(TGBridgeContext *)context
{
    if (chat.groupPhotoSmall.length > 0)
    {
        self.avatarInitialsLabel.hidden = true;
        self.avatarGroup.backgroundColor = [UIColor hexColor:0x222223];
        if (![_currentAvatarPhoto isEqualToString:chat.groupPhotoSmall])
        {
            _currentAvatarPhoto = chat.groupPhotoSmall;
            
            __weak TGUserRowController *weakSelf = self;
            [self.avatarGroup setBackgroundImageSignal:[[TGBridgeMediaSignals avatarWithPeerId:chat.identifier url:_currentAvatarPhoto type:TGBridgeMediaAvatarTypeSmall] onNext:^(id next)
            {
                __strong TGUserRowController *strongSelf = weakSelf;
                if (strongSelf != nil)
                    strongSelf->_currentAvatarPhoto = nil;
            }] isVisible:self.isVisible];
        }
    }
    else
    {
        self.avatarInitialsLabel.hidden = false;
        self.avatarGroup.backgroundColor = [TGColor colorForGroupId:chat.identifier];
        self.avatarInitialsLabel.text = [TGStringUtils initialForGroupName:chat.groupTitle];
        
        [self.avatarGroup setBackgroundImageSignal:nil isVisible:self.isVisible];
        _currentAvatarPhoto = nil;
    }
}

- (void)notifyVisiblityChange
{
    [self.avatarGroup updateIfNeeded];
}

+ (NSString *)identifier
{
    return TGUserRowIdentifier;
}

@end
