#import "TGNeoChatRowController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGBridgeUserCache.h"

#import "TGNeoChatViewModel.h"
#import "TGAvatarViewModel.h"

NSString *const TGNeoChatRowIdentifier = @"TGNeoChatRow";

@interface TGNeoChatRowController ()
{
    TGBridgeChat *_currentChat;
    NSDictionary *_currentUsers;
    
    TGNeoChatViewModel *_viewModel;
    SMetaDisposable *_renderDisposable;
    
    TGAvatarViewModel *_avatarViewModel;
    
    bool _pendingRendering;
}
@end

@implementation TGNeoChatRowController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _renderDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_renderDisposable dispose];
}

- (void)setupInterface
{
    [super setupInterface];
    
    _avatarViewModel = [[TGAvatarViewModel alloc] init];
    _avatarViewModel.group = self.avatarGroup;
    _avatarViewModel.label = self.avatarLabel;
    
    [self.avatarLabel _setInitialHidden:true];
    [self.statusGroup _setInitialHidden:true];
}

- (void)updateWithChat:(TGBridgeChat *)chat forForward:(bool)forForward context:(TGBridgeContext *)context
{
    TGBridgeChat *oldChat = _currentChat;
    _currentChat = chat;
    
    NSDictionary *oldUsers = _currentUsers;
    _currentUsers = [[TGBridgeUserCache instance] usersWithIds:[chat involvedUserIds]];

    bool shouldUpdate = [self shouldUpdateContentFrom:oldChat oldUsers:oldUsers to:_currentChat newUsers:_currentUsers];
    if (shouldUpdate)
    {
        _viewModel = [[TGNeoChatViewModel alloc] initWithChat:chat users:_currentUsers context:context];
        CGSize containerSize = [[WKInterfaceDevice currentDevice] screenBounds].size;
        CGSize contentSize = [_viewModel layoutWithContainerSize:containerSize];
        
        self.contentGroup.width = contentSize.width;
        self.contentGroup.height = contentSize.height;
        
        SSignal *signal = [TGNeoRenderableViewModel renderSignalForViewModel:_viewModel];
        
        __weak TGNeoChatRowController *weakSelf = self;
        [_renderDisposable setDisposable:[signal startWithNext:^(UIImage *image)
        {
            __strong TGNeoChatRowController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
        
            [strongSelf->_contentGroup setBackgroundImage:image];
        }]];
    }
    
    if (chat.isGroup || chat.isChannel)
        [_avatarViewModel updateWithChat:chat isVisible:self.isVisible];
    else
        [_avatarViewModel updateWithUser:_currentUsers[@(chat.identifier)] context:context isVisible:self.isVisible];
    
    if (forForward)
        return;
    
    bool shouldUpdateStatus = [self shouldUpdateStatusFrom:oldChat to:_currentChat];
    if (shouldUpdateStatus)
    {
        if ((chat.outgoing && chat.unread) || chat.deliveryError)
        {
            self.statusGroup.hidden = false;
            
            if (chat.deliveryError)
            {
                self.statusGroup.width = 15;
                self.statusLabel.text = @"!";
                self.statusLabel.hidden = false;
                self.statusGroup.backgroundColor = [UIColor hexColor:0xff4a5c];
                [self.statusGroup setBackgroundImageNamed:nil];
            }
            else if (!(_currentChat.identifier > 0 && [_currentUsers[@(_currentChat.identifier)] isBot]) && chat.unread)
            {
                self.statusGroup.width = 15;
                self.statusLabel.hidden = true;
                self.statusGroup.backgroundColor = [UIColor clearColor];
                [self.statusGroup setBackgroundImageNamed:@"StatusDot"];
            }
        }
        else if (!chat.outgoing && chat.unreadCount > 0)
        {
            self.statusGroup.hidden = false;
            self.statusLabel.text = [NSString stringWithFormat:@"%ld", (long)chat.unreadCount];
            self.statusLabel.hidden = false;
            if (chat.unreadCount < 10)
                self.statusGroup.width = 15;
            else
                [self.statusGroup sizeToFitWidth];
            self.statusGroup.backgroundColor = [UIColor hexColor:0x2ea4e5];
            [self.statusGroup setBackgroundImageNamed:nil];
        }
        else
        {
            self.statusGroup.hidden = true;
        }
    }
}

- (bool)_nameHasChangedFrom:(NSString *)oldName newName:(NSString *)newName
{
    return (![oldName isEqualToString:newName] && !(oldName == nil && newName == nil));
}

- (bool)shouldUpdateContentFrom:(TGBridgeChat *)oldChat oldUsers:(NSDictionary *)oldUsers to:(TGBridgeChat *)newChat newUsers:(NSDictionary *)newUsers
{
    if (oldChat == nil)
        return true;
    
    if (oldChat.identifier != newChat.identifier)
        return true;
    
    if (newChat.isGroup || newChat.isChannelGroup)
    {
        if (![oldChat.groupTitle isEqualToString:newChat.groupTitle])
            return true;
        
        if (oldChat.fromUid != newChat.fromUid)
            return true;
        
        TGBridgeUser *oldUser = oldUsers[@(oldChat.fromUid)];
        TGBridgeUser *newUser = newUsers[@(newChat.fromUid)];
        
        if ([self _nameHasChangedFrom:oldUser.firstName newName:newUser.firstName] || [self _nameHasChangedFrom:oldUser.lastName newName:newUser.firstName])
            return true;
    }
    else
    {
        TGBridgeUser *oldUser = oldUsers[@(oldChat.identifier)];
        TGBridgeUser *newUser = newUsers[@(newChat.identifier)];
        
        if ([self _nameHasChangedFrom:oldUser.firstName newName:newUser.firstName] || [self _nameHasChangedFrom:oldUser.lastName newName:newUser.firstName])
            return true;
    }
    
    if (![oldChat.text isEqualToString:newChat.text])
        return true;
    
    if (fabs(oldChat.date - newChat.date) > FLT_EPSILON)
        return true;
    
    return false;
}

- (void)notifyVisiblityChange
{
    [_avatarViewModel updateIfNeeded];
}

- (bool)shouldUpdateStatusFrom:(TGBridgeChat *)oldChat to:(TGBridgeChat *)newChat
{
    if (oldChat.outgoing != newChat.outgoing)
        return true;
    
    if (oldChat.deliveryError != newChat.deliveryError)
        return true;
    
    if (newChat.outgoing && oldChat.unread != newChat.unread)
        return true;
    
    if (!newChat.deliveryError && oldChat.unreadCount != newChat.unreadCount)
        return true;
    
    return false;
}

+ (NSString *)identifier
{
    return TGNeoChatRowIdentifier;
}

@end
