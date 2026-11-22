#import "TGGroupInfoHeaderController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGStringUtils.h"

#import "WKInterfaceGroup+Signals.h"
#import "TGBridgeMediaSignals.h"

NSString *const TGGroupInfoHeaderIdentifier = @"TGGroupInfoHeader";

@interface TGGroupInfoHeaderController ()
{
    NSString *_currentAvatarPhoto;
}
@end

@implementation TGGroupInfoHeaderController



- (void)updateWithGroupChat:(TGBridgeChat *)chat users:(NSDictionary *)users context:(TGBridgeContext *)context
{
    self.nameLabel.text = chat.groupTitle;
    
    NSInteger onlineCount = 1;
    for (NSNumber *uid in chat.participants)
    {
        TGBridgeUser *user = users[uid];
        if (user != nil && user.online && user.identifier != context.userId)
            onlineCount++;
    }
    
    NSString *membersText = [NSString stringWithFormat:TGLocalized([TGStringUtils integerValueFormat:@"Conversation.StatusMembers_" value:chat.participantsCount]), [NSString stringWithFormat:@"%d", (int32_t)chat.participantsCount]];
    
    if (onlineCount > 1)
        membersText = [NSString stringWithFormat:@"%@,", membersText];
    
    self.participantsLabel.text = membersText;
    
    self.onlineLabel.hidden = (onlineCount <= 1);
    if (!self.onlineLabel.hidden)
    {
        self.onlineLabel.text = [NSString stringWithFormat:TGLocalized([TGStringUtils integerValueFormat:@"Conversation.StatusOnline_" value:onlineCount]), [NSString stringWithFormat:@"%d", (int32_t)onlineCount]];
    }
    
    if (chat.groupPhotoSmall.length > 0)
    {
        self.avatarButton.enabled = true;
        self.avatarInitialsLabel.hidden = true;
        self.avatarGroup.backgroundColor = [UIColor hexColor:0x1a1a1a];
        if (![_currentAvatarPhoto isEqualToString:chat.groupPhotoSmall])
        {
            _currentAvatarPhoto = chat.groupPhotoSmall;
            
            __weak TGGroupInfoHeaderController *weakSelf = self;
            [self.avatarGroup setBackgroundImageSignal:[[TGBridgeMediaSignals avatarWithPeerId:chat.identifier url:_currentAvatarPhoto type:TGBridgeMediaAvatarTypeProfile] onError:^(id error)
            {
                __strong TGGroupInfoHeaderController *strongSelf = weakSelf;
                if (strongSelf != nil)
                    strongSelf->_currentAvatarPhoto = nil;
            }] isVisible:self.isVisible];
        }
    }
    else
    {
        self.avatarButton.enabled = false;
        self.avatarInitialsLabel.hidden = false;
        self.avatarGroup.backgroundColor = [TGColor colorForGroupId:chat.identifier];
        self.avatarInitialsLabel.text = [TGStringUtils initialForGroupName:chat.groupTitle];
        
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
    return TGGroupInfoHeaderIdentifier;
}

@end
