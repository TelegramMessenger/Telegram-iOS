#import "TGAvatarViewModel.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGStringUtils.h"
#import "TGWatchColor.h"

#import "WKInterfaceGroup+Signals.h"
#import "TGBridgeMediaSignals.h"

@interface TGAvatarViewModel ()
{
    TGBridgeUser *_currentUser;
    TGBridgeChat *_currentChat;
}
@end

@implementation TGAvatarViewModel

- (void)updateWithUser:(TGBridgeUser *)user context:(TGBridgeContext *)context isVisible:(bool (^)(void))isVisible
{
    TGBridgeUser *oldUser = _currentUser;
    _currentUser = user;
    
    if (_currentUser.identifier == context.userId)
    {
        self.label.hidden = true;
        self.group.backgroundColor = [UIColor hexColor:0x222223];
        [self.group setBackgroundImageSignal:[SSignal single:@"SavedMessagesAvatar"] isVisible:isVisible];
    }
    else if (_currentUser.photoSmall.length > 0)
    {
        if (![_currentUser.photoSmall isEqualToString:oldUser.photoSmall])
        {
            self.label.hidden = true;
            self.group.backgroundColor = [UIColor hexColor:0x222223];
            
            __block bool completed = false;
            
            __weak TGAvatarViewModel *weakSelf = self;
            [self.group setBackgroundImageSignal:[[[TGBridgeMediaSignals avatarWithPeerId:_currentUser.identifier url:_currentUser.photoSmall type:TGBridgeMediaAvatarTypeSmall] onNext:^(id next)
            {
                completed = true;
            }] onDispose:^
            {
                __strong TGAvatarViewModel *strongSelf = weakSelf;
                
                if (strongSelf != nil && !completed)
                    strongSelf->_currentUser = nil;
            }] isVisible:isVisible];
        }
    }
    else
    {
         if (oldUser.photoSmall.length > 0 || ![[oldUser displayName] isEqualToString:[_currentUser displayName]])
         {
             self.label.hidden = false;
             self.label.text = [TGStringUtils initialsForFirstName:_currentUser.firstName lastName:_currentUser.lastName single:true];
             self.group.backgroundColor = [TGColor colorForUserId:(int32_t)user.identifier myUserId:context.userId];
         }
    }
}

- (void)updateWithChat:(TGBridgeChat *)chat isVisible:(bool (^)(void))isVisible
{
    TGBridgeChat *oldChat = _currentChat;
    _currentChat = chat;
    
    if (_currentChat.groupPhotoSmall.length > 0)
    {
        if (![_currentChat.groupPhotoSmall isEqualToString:oldChat.groupPhotoSmall])
        {
            self.label.hidden = true;
            self.group.backgroundColor = [UIColor hexColor:0x222223];
            
            __block bool completed = false;
            
            __weak TGAvatarViewModel *weakSelf = self;
            [self.group setBackgroundImageSignal:[[[TGBridgeMediaSignals avatarWithPeerId:_currentChat.identifier url:_currentChat.groupPhotoSmall type:TGBridgeMediaAvatarTypeSmall] onNext:^(id next)
            {
                completed = true;
            }] onDispose:^
            {
                __strong TGAvatarViewModel *strongSelf = weakSelf;
                
                if (strongSelf != nil && !completed)
                    strongSelf->_currentChat = nil;
            }] isVisible:isVisible];
        }
    }
    else
    {
        if (oldChat.groupPhotoSmall.length > 0 || ![[oldChat groupTitle] isEqualToString:[_currentChat groupTitle]])
        {
            self.label.hidden = false;
            self.label.text = [TGStringUtils initialForGroupName:_currentChat.groupTitle];
            self.group.backgroundColor = [TGColor colorForGroupId:_currentChat.identifier];
        }
    }
}

- (void)updateIfNeeded
{
    [self.group updateIfNeeded];
}

@end
