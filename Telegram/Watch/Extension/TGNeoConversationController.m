#import "TGNeoConversationController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGNeoChatsController.h"

#import "TGStringUtils.h"
#import "TGDateUtils.h"

#import "WKInterfaceTable+TGDataDrivenTable.h"
#import "TGTableDeltaUpdater.h"
#import "TGInterfaceMenu.h"

#import "TGBridgeClient.h"
#import "TGBridgeMessage+TGTableItem.h"
#import "TGBridgeBotReplyMarkup.h"
#import "TGBridgeUserCache.h"

#import "TGChatInfo.h"

#import "TGBridgeChatMessageListSignals.h"
#import "TGBridgeConversationSignals.h"
#import "TGBridgePeerSettingsSignals.h"
#import "TGBridgeSendMessageSignals.h"
#import "TGBridgeBotSignals.h"
#import "TGBridgeStateSignal.h"
#import "TGBridgeRemoteSignals.h"
#import "TGBridgeAudioSignals.h"

#import "TGNeoConversationRowController.h"
#import "TGNeoConversationStaticRowController.h"
#import "TGNeoConversationTimeRowController.h"
#import "TGConversationFooterController.h"

#import "TGUserInfoController.h"
#import "TGGroupInfoController.h"
#import "TGBotCommandController.h"
#import "TGBotKeyboardController.h"
#import "TGStickersController.h"
#import "TGLocationController.h"
#import "TGInputController.h"
#import "TGMessageViewController.h"
#import "TGAudioMicAlertController.h"

NSString *const TGNeoConversationControllerIdentifier = @"TGNeoConversationController";
const NSInteger TGNeoConversationControllerDefaultBatchLimit = 8;
const NSInteger TGNeoConversationControllerPerformantBatchLimit = 10;
const NSInteger TGNeoConversationControllerMaximumBatchLimit = 20;

const NSInteger TGNeoConversationControllerInitialRenderCount = 4;

@interface TGNeoConversationControllerContext ()
{
    int64_t _peerId;
    SVariable *_messages;
}

@property (nonatomic, readonly) SSignal *signal;
@property (nonatomic, readonly) bool shouldReadMessages;

@end

@implementation TGNeoConversationControllerContext

- (instancetype)initWithChat:(TGBridgeChat *)chat
{
    self = [super init];
    if (self != nil)
    {
        _chat = chat;
        
        [self initialize];
    }
    return self;
}

- (instancetype)initWithPeerId:(int64_t)peerId
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        
        [self initialize];
    }
    return self;
}

- (void)initialize
{
    _shouldReadMessages = true;
    
    NSInteger rangeCount = TGNeoConversationControllerDefaultBatchLimit;
    switch (TGWatchScreenType()) {
        case TGScreenType40mm:
        case TGScreenType44mm:
            rangeCount = TGNeoConversationControllerPerformantBatchLimit;
            break;
            
        default:
            break;
    }
    NSInteger initialUnreadCount = _chat.unreadCount;
    if (initialUnreadCount > 0)
    {
        rangeCount = MAX(TGNeoConversationControllerDefaultBatchLimit, MIN(TGNeoConversationControllerMaximumBatchLimit, initialUnreadCount));
        
        if (initialUnreadCount > TGNeoConversationControllerMaximumBatchLimit)
            _shouldReadMessages = false;
    }

    _messages = [[SVariable alloc] init];
    SSignal *loadSignal = [TGBridgeChatMessageListSignals chatMessageListViewWithPeerId:self.peerId atMessageId:0 rangeMessageCount:rangeCount];
    loadSignal = [loadSignal timeout:7.5 onQueue:[SQueue mainQueue] orSignal:loadSignal];
    
    [_messages set:[loadSignal deliverOn:[SQueue mainQueue]]];
}

- (int64_t)peerId
{
    if (_peerId == 0)
        return _chat.identifier;
    
    return _peerId;
}

- (SSignal *)signal
{
    return _messages.signal;
}

@end

@interface TGNeoConversationController () <TGTableDataSource>
{
    TGNeoConversationControllerContext *_context;
    
    SMetaDisposable *_messagesListDisposable;
    SMetaDisposable *_chatGroupDisposable;
    SMetaDisposable *_sendMessageDisposable;
    SMetaDisposable *_readMessagesDisposable;
    SMetaDisposable *_peerSettingsDisposable;
    SMetaDisposable *_updateSettingsDisposable;
    SMetaDisposable *_botInfoDisposable;
    SMetaDisposable *_botReplyMarkupDisposable;
    SMetaDisposable *_remoteActionDisposable;
    
    SMetaDisposable *_sentMediaDisposable;
    SMetaDisposable *_playAudioDisposable;
    TGBridgeMediaAttachment *_pendingAudioAttachment;
    
    TGBridgeChat *_chatModel;
    NSArray *_messageModels;
    TGBridgeBotInfo *_botInfo;
    TGBridgeBotReplyMarkup *_botReplyMarkup;
    NSDictionary *_peerModels;
    
    NSMutableArray *_pendingSentMessages;
    bool _shouldReadMessages;
    
    bool _muted;
    bool _blocked;
    bool _hasBots;
    
    NSArray *_rowModels;
    
    bool _initialized;
    bool _initialRendering;
    bool _shouldScrollToBottom;
    TGInterfaceMenu *_menu;
    TGConversationFooterOptions _footerOptions;
    bool _dontAnimateFooterTransition;
}
@end

@implementation TGNeoConversationController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _messagesListDisposable = [[SMetaDisposable alloc] init];
        _chatGroupDisposable = [[SMetaDisposable alloc] init];
        _sendMessageDisposable = [[SMetaDisposable alloc] init];
        _readMessagesDisposable = [[SMetaDisposable alloc] init];
        _peerSettingsDisposable = [[SMetaDisposable alloc] init];
        _updateSettingsDisposable = [[SMetaDisposable alloc] init];
        _botInfoDisposable = [[SMetaDisposable alloc] init];
        _botReplyMarkupDisposable = [[SMetaDisposable alloc] init];
        _remoteActionDisposable = [[SMetaDisposable alloc] init];
        _sentMediaDisposable = [[SMetaDisposable alloc] init];
        _playAudioDisposable = [[SMetaDisposable alloc] init];
        
        _pendingSentMessages = [[NSMutableArray alloc] init];
        
        _dontAnimateFooterTransition = true;
        
        self.table.reloadDataReversed = true;
        self.table.tableDataSource = self;
        [self.table _setInitialHidden:true];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextUpdated:) name:TGContextNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [_messagesListDisposable dispose];
    [_chatGroupDisposable dispose];
    [_sendMessageDisposable dispose];
    [_readMessagesDisposable dispose];
    [_peerSettingsDisposable dispose];
    [_updateSettingsDisposable dispose];
    [_botInfoDisposable dispose];
    [_botReplyMarkupDisposable dispose];
    [_remoteActionDisposable dispose];
    [_sentMediaDisposable dispose];
    [_playAudioDisposable dispose];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)configureWithContext:(TGNeoConversationControllerContext *)context
{
    _context = context;
 
    if (context.finished != nil)
        context.finished();
    
    if (_context.chat.identifier < 0)
        _chatModel = _context.chat;
    
    self.title = [self conversationTitle];
    
    _shouldReadMessages = context.shouldReadMessages;
    
    __weak TGNeoConversationController *weakSelf = self;
    [_messagesListDisposable setDisposable:[context.signal startWithNext:^(NSDictionary *models)
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_shouldScrollToBottom = (strongSelf->_messageModels == nil);
        
        strongSelf->_messageModels = models[TGBridgeMessagesArrayKey];
        
        [[TGBridgeUserCache instance] storeUsers:[models[TGBridgeUsersDictionaryKey] allValues]];
        strongSelf->_peerModels = models[TGBridgeUsersDictionaryKey];
        
        [strongSelf _readMessagesIfNeeded];
        
        [strongSelf performInterfaceUpdate:^(bool animated)
        {
            __strong TGNeoConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf reloadData];
        }];
    }]];
    
    if ([self peerIsAnyGroup])
    {
        [_chatGroupDisposable setDisposable:[[[TGBridgeConversationSignals conversationWithPeerId:[self peerId]] deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *next)
        {
            __strong TGNeoConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_chatModel = next[TGBridgeChatKey];
            [[TGBridgeUserCache instance] storeUsers:[next[TGBridgeUsersDictionaryKey] allValues]];
            
            [strongSelf _updateBots];
            
            [strongSelf performInterfaceUpdate:^(bool animated)
            {
                __strong TGNeoConversationController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf reloadData];
            }];
        }]];
    }
//    else
//    {
//        [self _updateBots];
//        if (_hasBots)
//        {
//            [_botInfoDisposable setDisposable:[[TGBridgeBotSignals botInfoForUserId:(int32_t)[self peerId]] startWithNext:^(TGBridgeBotInfo *next)
//            {
//                __strong TGNeoConversationController *strongSelf = weakSelf;
//                if (strongSelf == nil)
//                    return;
//
//                strongSelf->_botInfo = next;
//
//                [strongSelf performInterfaceUpdate:^(bool animated)
//                {
//                    __strong TGNeoConversationController *strongSelf = weakSelf;
//                    if (strongSelf == nil)
//                        return;
//
//                    [strongSelf reloadData];
//                }];
//            }]];
//        }
//    }
    
//    if ([self peerIsAnyGroup] || _hasBots)
//    {
//        [_botReplyMarkupDisposable setDisposable:[[TGBridgeBotSignals botReplyMarkupForPeerId:[self peerId]] startWithNext:^(TGBridgeBotReplyMarkup *next)
//        {
//            __strong TGNeoConversationController *strongSelf = weakSelf;
//            if (strongSelf == nil)
//                return;
//
//            strongSelf->_botReplyMarkup = next;
//
//            [strongSelf performInterfaceUpdate:^(bool animated)
//            {
//                __strong TGNeoConversationController *strongSelf = weakSelf;
//                if (strongSelf == nil)
//                    return;
//
//                [strongSelf reloadData];
//            }];
//        }]];
//    }
    
    [_peerSettingsDisposable setDisposable:[[[TGBridgePeerSettingsSignals peerSettingsWithPeerId:[self peerId]] deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *next)
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        bool blocked = [next[@"blocked"] boolValue];
        bool muted = [next[@"muted"] boolValue];
        
        strongSelf->_blocked = blocked;
        strongSelf->_muted = muted;
        
        [strongSelf performInterfaceUpdate:^(bool animated)
        {
            __strong TGNeoConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf reloadData];
        }];
    }]];
    
    [_sentMediaDisposable setDisposable:[[TGBridgeAudioSignals sentAudioForConversationId:[self peerId]] startWithNext:nil]];
    
    [self configureHandoff];
}

- (void)reloadData
{
    NSArray *currentRowModels = _rowModels;
    NSMutableArray *rowModels = [TGNeoConversationController reversedMessagesArray:_messageModels];
    if (rowModels == nil)
        return;
    
    TGConversationFooterOptions oldFooterOptions = _footerOptions;
    
    _footerOptions = TGConversationFooterOptionsSendMessage;
    if (_chatModel.isKickedFromGroup || _chatModel.hasLeftGroup)
        _footerOptions = TGConversationFooterOptionsInactive;
    else if (_blocked)
        _footerOptions = [self _userIsBot] ? TGConversationFooterOptionsRestartBot : TGConversationFooterOptionsUnblock;
    else if (![self peerIsGroup] && _hasBots && _messageModels != nil && _messageModels.count == 0)
        _footerOptions = TGConversationFooterOptionsStartBot;
    
    if (_footerOptions == TGConversationFooterOptionsSendMessage && _hasBots)
    {
        if (_botReplyMarkup.rows.count > 0)
            _footerOptions |= TGConversationFooterOptionsBotKeyboard;
        else
            _footerOptions |= TGConversationFooterOptionsBotCommands;
    }
    if ([self peerIsAnyGroup] || !_hasBots)
        _footerOptions |= TGConversationFooterOptionsVoice;
    
    NSMutableArray *pendingSentMessages = [[NSMutableArray alloc] init];
    for (TGBridgeMessage *message in _pendingSentMessages)
    {
        TGBridgeDocumentMediaAttachment *documentAttachment = nil;
        TGBridgeLocationMediaAttachment *locationAttachment = nil;
        TGBridgeAudioMediaAttachment *audioAttachment = nil;
        
        for (TGBridgeMediaAttachment *attachment in message.media)
        {
            if ([attachment isKindOfClass:[TGBridgeDocumentMediaAttachment class]])
                documentAttachment = (TGBridgeDocumentMediaAttachment *)attachment;
            else if ([attachment isKindOfClass:[TGBridgeLocationMediaAttachment class]])
                locationAttachment = (TGBridgeLocationMediaAttachment *)attachment;
            else if ([attachment isKindOfClass:[TGBridgeAudioMediaAttachment class]])
                audioAttachment = (TGBridgeAudioMediaAttachment *)attachment;
        }
        
        bool skip = false;
        
        for (TGBridgeMessage *realMessage in rowModels)
        {
            if (!realMessage.outgoing)
                continue;
            
            if (fabs(realMessage.date - message.date) > 4.0)
                continue;
            
            if ([realMessage.text isEqualToString:message.text])
            {
                skip = true;
            }
            else
            {
                TGBridgeDocumentMediaAttachment *realDocumentAttachment = nil;
                TGBridgeLocationMediaAttachment *realLocationAttachment = nil;
                TGBridgeAudioMediaAttachment *realAudioAttachment = nil;
                
                for (TGBridgeMediaAttachment *attachment in message.media)
                {
                    if ([attachment isKindOfClass:[TGBridgeDocumentMediaAttachment class]])
                        realDocumentAttachment = (TGBridgeDocumentMediaAttachment *)attachment;
                    else if ([attachment isKindOfClass:[TGBridgeLocationMediaAttachment class]])
                        realLocationAttachment = (TGBridgeLocationMediaAttachment *)attachment;
                    else if ([attachment isKindOfClass:[TGBridgeAudioMediaAttachment class]])
                        realAudioAttachment = (TGBridgeAudioMediaAttachment *)attachment;
                }
                
                if ([realDocumentAttachment isEqual:documentAttachment] || [realLocationAttachment isEqual:locationAttachment] || [realAudioAttachment isEqual:audioAttachment])
                {
                    skip = true;
                }
            }
        }
        
        if (!skip)
            [pendingSentMessages addObject:message];
    }
    _pendingSentMessages = pendingSentMessages;
    
    for (TGBridgeMessage *message in pendingSentMessages)
        [rowModels addObject:message];
    
//    if (_botInfo.botDescription.length > 0)
//    {
//        TGChatInfo *chatInfo = [[TGChatInfo alloc] init];
//        chatInfo.title = TGLocalized(@"Bot.DescriptionTitle");
//        chatInfo.text = _botInfo.botDescription;
//        [rowModels insertObject:chatInfo atIndex:0];
//    }
    
    _rowModels = [TGNeoConversationController timestampedModelsArray:rowModels];
    
    bool initial = (currentRowModels == nil);
    if (!initial)
    {
        [TGTableDeltaUpdater updateTable:self.table oldData:currentRowModels newData:_rowModels controllerClassForIndexPath:^Class(TGIndexPath *indexPath)
        {
            return [self table:self.table rowControllerClassAtIndexPath:indexPath];
        }];
        
        if (oldFooterOptions != _footerOptions)
            [self.table reloadFooter];
    }
    else
    {
        _initialRendering = true;
        
        [self.table reloadData];
        self.activityIndicator.hidden = true;
        self.table.hidden = false;
    }
    
    if (_shouldScrollToBottom)
    {
        _shouldScrollToBottom = false;
        
        if (!_initialized)
        {
            [self animateWithDuration:0.4 animations:^
            {
                self.table.alpha = 1.0f;
            }];
            
            _initialized = true;
        }
        [self.table scrollToRowAtIndexPath:[TGIndexPath indexPathForRow:_rowModels.count - 1 inSection:0]];
        
        if (_initialRendering)
        {
            TGDispatchAfter(1.2, dispatch_get_main_queue(), ^
            {
                _initialRendering = false;
                [self.table reloadAllRows];
            });
        }
    }
    
    [self updateMenuItems];
}

- (NSString *)conversationTitle
{
    if ([self peerIsGroup] || [self peerIsChannel])
        return _chatModel.groupTitle;
    else if (_context.context.userId == _context.peerId)
        return TGLocalized(@"Conversation.SavedMessages");
    else
        return [[[TGBridgeUserCache instance] userWithId:(int32_t)[self peerId]] displayName];
}

- (void)configureHandoff
{
    int64_t peerId = [self peerId];
    bool isGroup = [self peerIsGroup] || [self peerIsChannel];
    
    if (isGroup)
        peerId = -peerId;
    
    NSMutableDictionary *peerDict = [[NSMutableDictionary alloc] init];
    peerDict[@"type"] = isGroup ? @"group" : @"user";
    peerDict[@"id"] = @(peerId);
    
    NSDictionary *userInfo = @{@"user_id": @(_context.context.userId), @"peer": peerDict};
    [self updateUserActivity:@"org.telegram.conversation" userInfo:userInfo webpageURL:[NSURL URLWithString:@"https://telegram.org/dl"]];
}

#pragma mark -

- (void)contextUpdated:(NSNotification *)notification
{
    TGBridgeContext *context = notification.userInfo[TGContextNotificationKey];
    if (context != nil)
        _context.context = context;
}

- (void)updateTitleWithState:(TGBridgeSynchronizationStateValue)value
{
    NSString *state = [TGNeoChatsController stringForSyncState:value];
    if (_context.context == nil || state == nil)
        self.title = [self conversationTitle];
    else
        self.title = state;
}

- (void)updateMenuItems
{
    [_menu clearItems];
    
    if (_context.chat.isKickedFromGroup || _context.chat.hasLeftGroup)
        return;
    
    if (_menu == nil)
        _menu = [[TGInterfaceMenu alloc] initForInterfaceController:self];
    
    NSMutableArray *menuItems = [[NSMutableArray alloc] init];
    
    __weak TGNeoConversationController *weakSelf = self;
    TGInterfaceMenuItem *infoItem = [[TGInterfaceMenuItem alloc] initWithItemIcon:WKMenuItemIconInfo title:[self peerIsAnyGroup] ? TGLocalized(@"Watch.Conversation.GroupInfo") : TGLocalized(@"Watch.Conversation.UserInfo") actionBlock:^(TGInterfaceController *controller, TGInterfaceMenuItem *sender)
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([strongSelf peerIsGroup])
        {
            TGGroupInfoControllerContext *context = [[TGGroupInfoControllerContext alloc] initWithGroupChat:strongSelf->_context.chat];
            [controller pushControllerWithClass:[TGGroupInfoController class] context:context];
        }
        else if ([strongSelf peerIsChannel])
        {
            TGUserInfoControllerContext *context = [[TGUserInfoControllerContext alloc] initWithChannel:strongSelf->_chatModel];
            context.disallowCompose = true;
            [controller pushControllerWithClass:[TGUserInfoController class] context:context];
        }
        else
        {
            TGUserInfoControllerContext *context = [[TGUserInfoControllerContext alloc] initWithUserId:(int32_t)[strongSelf peerId]];
            context.disallowCompose = true;
            [controller pushControllerWithClass:[TGUserInfoController class] context:context];
        }
    }];
    [menuItems addObject:infoItem];
    
    bool muted = _muted;
    bool blocked = _blocked;
    
    bool muteForever = [self peerIsAnyGroup];
    int32_t muteFor = muteForever ? INT_MAX : 1;
    NSString *muteTitle = muteForever ? TGLocalized(@"Watch.UserInfo.MuteTitle") : [NSString stringWithFormat:TGLocalized([TGStringUtils integerValueFormat:@"Watch.UserInfo.Mute_" value:muteFor]), muteFor];
    
    TGInterfaceMenuItem *muteItem = [[TGInterfaceMenuItem alloc] initWithItemIcon:muted ? WKMenuItemIconSpeaker : WKMenuItemIconMute title:muted ? TGLocalized(@"Watch.UserInfo.Unmute") : muteTitle actionBlock:^(TGInterfaceController *controller, TGInterfaceMenuItem *sender)
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_updateSettingsDisposable setDisposable:[[[TGBridgePeerSettingsSignals toggleMutedWithPeerId:[strongSelf peerId]] deliverOn:[SQueue mainQueue]] startWithNext:nil completed:^
        {
            __strong TGNeoConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_muted = !muted;
            
            [strongSelf performInterfaceUpdate:^(bool animated)
            {
                __strong TGNeoConversationController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf reloadData];
            }];
        }]];
    }];
    [menuItems addObject:muteItem];
    
    if (![self peerIsGroup] && ![self peerIsChannel])
    {
        TGInterfaceMenuItem *blockItem = [[TGInterfaceMenuItem alloc] initWithItemIcon:WKMenuItemIconBlock title:blocked ? TGLocalized(@"Watch.UserInfo.Unblock") : TGLocalized(@"Watch.UserInfo.Block") actionBlock:^(TGInterfaceController *controller, TGInterfaceMenuItem *sender)
        {
            __strong TGNeoConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_updateSettingsDisposable setDisposable:[[[TGBridgePeerSettingsSignals updateBlockStatusWithPeerId:[strongSelf peerId] blocked:!blocked] deliverOn:[SQueue mainQueue]] startWithNext:nil completed:^
            {
                __strong TGNeoConversationController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf->_blocked = !blocked;
                
                [strongSelf performInterfaceUpdate:^(bool animated)
                {
                    __strong TGNeoConversationController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    [strongSelf reloadData];
                }];
            }]];
        }];
        [menuItems addObject:blockItem];
    }
    
    [_menu addItems:menuItems];
}


#pragma mark - Peer

- (int64_t)peerId
{
    return _context.peerId;
}

- (bool)peerIsGroup
{
    if (_chatModel != nil)
        return _chatModel.isGroup;
    else
        return _context.peerId < 0;
}

- (bool)peerIsChannel
{
    if (_chatModel != nil)
        return _chatModel.isChannel;
    else
        return false;
}

- (bool)peerIsChannelGroup
{
    if (_chatModel != nil)
        return _chatModel.isChannelGroup;
    else
        return false;
}

- (bool)peerIsAnyGroup
{
    return [self peerIsGroup] || [self peerIsChannelGroup];
}

#pragma mark - Bots

- (SSignal *)botCommandListSignal
{
    if (!_hasBots)
        return nil;
    
    if ([self peerIsAnyGroup])
    {
        NSMutableArray *botInfoSignals = [[NSMutableArray alloc] init];
        NSMutableArray *botUsers = [[NSMutableArray alloc] init];
        NSMutableArray *initialStates = [[NSMutableArray alloc] init];
        
        for (NSNumber *nId in _chatModel.participantsUserIds) {
            int64_t idx = [nId longLongValue];
            TGBridgeUser *user = [[TGBridgeUserCache instance] userWithId:idx];
            if ([user isBot])
            {
                [botUsers addObject:user];
                [initialStates addObject:@[]];
                [botInfoSignals addObject:[[TGBridgeBotSignals botInfoForUserId:user.identifier] map:^NSArray *(TGBridgeBotInfo *botInfo)
                {
                    if (botInfo.commandList == nil)
                        return @[];
                    
                    return botInfo.commandList;
                }]];
            }
        }
        
        return [[SSignal combineSignals:botInfoSignals withInitialStates:initialStates] map:^id(NSArray *commandLists)
        {
            NSMutableArray *commands = [[NSMutableArray alloc] init];
            NSInteger index = 0;
            for (NSArray *commandList in commandLists)
            {
                [commands addObject:@{ TGBotCommandUserKey: botUsers[index], TGBotCommandListKey: commandList } ];
                index++;
            }
            
            return commands;
        }];
    }
    else if ([self _userIsBot])
    {
        int32_t userId = (int32_t)[self peerId];
        return [[TGBridgeBotSignals botInfoForUserId:userId] map:^NSArray *(TGBridgeBotInfo *botInfo)
        {
            if (botInfo != nil)
            {
                TGBridgeUser *user = [[TGBridgeUserCache instance] userWithId:userId];
                return @[ @{ TGBotCommandUserKey: user, TGBotCommandListKey: botInfo.commandList } ];
            }
            
            return nil;
        }];
    }
    
    return nil;
}

- (bool)_userIsBot
{
    if ([self peerId] < 0)
        return false;
    
    TGBridgeUser *user = [[TGBridgeUserCache instance] userWithId:(int32_t)[self peerId]];
    return [user isBot];
}

- (void)_updateBots
{
    _hasBots = false;
    return;
    
    if ([self peerIsAnyGroup])
    {
        for (NSNumber *nId in _chatModel.participantsUserIds) {
            int64_t userId = [nId longLongValue];
            TGBridgeUser *user = [[TGBridgeUserCache instance] userWithId:userId];
            if ([user isBot]) {
                _hasBots = true;
                break;
            }
        }
    }
    else
    {
        TGBridgeUser *user = [[TGBridgeUserCache instance] userWithId:(int32_t)[self peerId]];
        _hasBots = [user isBot];
    }
}

#pragma mark -

- (void)sendMessageWithText:(NSString *)text
{
    [self sendMessageWithText:text replyToMessage:nil];
}

- (void)sendMessageWithText:(NSString *)text replyToMessage:(TGBridgeMessage *)replyToMessage
{
    _shouldReadMessages = true;
    _shouldScrollToBottom = true;
    
    [_pendingSentMessages addObject:[TGBridgeMessage temporaryNewMessageForText:text userId:_context.context.userId replyToMessage:replyToMessage]];
    
    __weak TGNeoConversationController *weakSelf = self;
    [self performInterfaceUpdate:^(bool animated)
    {
         __strong TGNeoConversationController *strongSelf = weakSelf;
         if (strongSelf == nil)
             return;
        
        [strongSelf reloadData];
    }];
    
    [_sendMessageDisposable setDisposable:[[[TGBridgeSendMessageSignals sendMessageWithPeerId:[self peerId] text:text replyToMid:0] deliverOn:[SQueue mainQueue]] startWithNext:nil]];
}

- (void)sendMessageWithStickerAttachment:(TGBridgeDocumentMediaAttachment *)sticker
{
    _shouldReadMessages = true;
    _shouldScrollToBottom = true;
    
    [_pendingSentMessages addObject:[TGBridgeMessage temporaryNewMessageForSticker:sticker userId:_context.context.userId]];
    
    __weak TGNeoConversationController *weakSelf = self;
    [self performInterfaceUpdate:^(bool animated)
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf reloadData];
    }];
    
    [_sendMessageDisposable setDisposable:[[[TGBridgeSendMessageSignals sendMessageWithPeerId:[self peerId] sticker:sticker replyToMid:0] deliverOn:[SQueue mainQueue]] startWithNext:nil]];
}

- (void)sendMessageWithLocationAttachment:(TGBridgeLocationMediaAttachment *)location
{
    _shouldReadMessages = true;
    _shouldScrollToBottom = true;
    
    [_pendingSentMessages addObject:[TGBridgeMessage temporaryNewMessageForLocation:location userId:_context.context.userId]];
    
    __weak TGNeoConversationController *weakSelf = self;
    [self performInterfaceUpdate:^(bool animated)
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf reloadData];
    }];
    
    [_sendMessageDisposable setDisposable:[[[TGBridgeSendMessageSignals sendMessageWithPeerId:[self peerId] location:location replyToMid:0] deliverOn:[SQueue mainQueue]] startWithNext:nil]];
}

- (void)sendAudioWithUniqueId:(int64_t)uniqueId duration:(int32_t)duration url:(NSURL *)url
{
    _shouldReadMessages = true;
    _shouldScrollToBottom = true;
    
    [_pendingSentMessages addObject:[TGBridgeMessage temporaryNewMessageForAudioWithDuration:duration userId:_context.context.userId localAudioId:uniqueId]];
    
    __weak TGNeoConversationController *weakSelf = self;
    [self performInterfaceUpdate:^(bool animated)
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
         
        [strongSelf reloadData];
    }];
    
    NSDictionary *metadata = @
    {
        TGBridgeIncomingFileTypeKey: TGBridgeIncomingFileTypeAudio,
        TGBridgeIncomingFileRandomIdKey: @(uniqueId),
        TGBridgeIncomingFilePeerIdKey: @([self peerId]),
        TGBridgeIncomingFileReplyToMidKey: @(0)
    };
    
    [[TGBridgeClient instance] sendFileWithURL:url metadata:metadata];
}

- (TGBridgeMessage *)_latestIncomingMessage
{
    __block TGBridgeMessage *incomingMessage = nil;
    
    for (TGBridgeMessage *message in _messageModels)
    {
        if (!message.outgoing)
        {
            incomingMessage = message;
            break;
        }
    }
    return incomingMessage;
}

- (void)_readMessagesIfNeeded
{
    bool hasUnreadMessages = false;
    for (TGBridgeMessage *message in _messageModels)
    {
        if (!message.outgoing && message.unread)
        {
            hasUnreadMessages = true;
            break;
        }
    }
    
    if (hasUnreadMessages && _shouldReadMessages)
    {
        TGBridgeMessage *lastMessage = [self _latestIncomingMessage];
        [_readMessagesDisposable setDisposable:[[TGBridgeChatMessageListSignals readChatMessageListWithPeerId:[self peerId] messageId:lastMessage.identifier] startWithNext:nil completed:nil]];
    }
}

#pragma mark - Table Data Source & Delegate

- (Class)table:(WKInterfaceTable *)table rowControllerClassAtIndexPath:(TGIndexPath *)indexPath
{
    id model = _rowModels[indexPath.row];
    
    if ([model isKindOfClass:[TGBridgeMessage class]])
    {
        return [TGNeoRowController rowControllerClassForMessage:(TGBridgeMessage *)model];
    }
    else if ([model isKindOfClass:[TGChatInfo class]])
    {
        return [TGNeoConversationStaticRowController class];
    }
    else if ([model isKindOfClass:[TGChatTimestamp class]])
    {
        return [TGNeoConversationTimeRowController class];
    }
    
    return nil;
}

- (NSUInteger)numberOfRowsInTable:(WKInterfaceTable *)table section:(NSUInteger)section
{
    return _rowModels.count;
}

- (void)table:(WKInterfaceTable *)table updateRowController:(TGTableRowController *)controller forIndexPath:(TGIndexPath *)indexPath
{
    if (![controller isKindOfClass:[TGTableRowController class]])
        return;
    
    __weak TGNeoConversationController *weakSelf = self;
    
    id model = _rowModels[indexPath.row];
    NSUInteger index = [self numberOfRowsInTable:self.table section:0] - indexPath.row - 1;
    
    if ([model isKindOfClass:[TGChatTimestamp class]] && [controller isKindOfClass:[TGNeoConversationTimeRowController class]])
    {
        TGNeoConversationTimeRowController *timeController = (TGNeoConversationTimeRowController *)controller;
        [timeController updateWithTimestamp:model];
        return;
    }
    
    if ([controller isKindOfClass:[TGNeoRowController class]]) {
        TGNeoRowController *rowController = (TGNeoRowController *)controller;
        rowController.shouldRenderContent = ^bool
        {
            __strong TGNeoConversationController *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_initialRendering && index >= TGNeoConversationControllerInitialRenderCount)
                return false;
            
            return true;
        };
    }
    
    if ([model isKindOfClass:[TGBridgeMessage class]])
    {
        TGBridgeMessage *message = (TGBridgeMessage *)model;
        
        TGNeoConversationRowController *conversationRow = (TGNeoConversationRowController *)controller;
        __weak TGNeoConversationRowController *weakConversationRow = conversationRow;
       
        conversationRow.animate = ^(void (^animations)(void))
        {
            __strong TGNeoConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf animateWithDuration:0.25 animations:animations];
        };
        
        conversationRow.buttonPressed = ^
        {
            __strong TGNeoConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            TGBridgeMediaAttachment *audioAttachment = nil;
            for (TGBridgeMediaAttachment *attachment in message.media)
            {
                if ([attachment isKindOfClass:[TGBridgeAudioMediaAttachment class]])
                {
                    audioAttachment = (TGBridgeAudioMediaAttachment *)attachment;
                }
                else if ([attachment isKindOfClass:[TGBridgeDocumentMediaAttachment class]])
                {
                    TGBridgeDocumentMediaAttachment *documentAttachment = (TGBridgeDocumentMediaAttachment *)attachment;
                    if (documentAttachment.isVoice)
                        audioAttachment = documentAttachment;
                }
            }
            
            if (audioAttachment != nil)
            {
                __strong TGNeoConversationRowController *strongConversationRow = weakConversationRow;
                if ([strongSelf->_pendingAudioAttachment isEqual:audioAttachment])
                {
                    if (strongConversationRow != nil)
                        [strongConversationRow setProcessingState:false];
                 
                    strongSelf->_pendingAudioAttachment = nil;
                    
                    [strongSelf->_playAudioDisposable setDisposable:nil];
                }
                else
                {
                    if (strongConversationRow != nil)
                        [strongConversationRow setProcessingState:true];
                    
                    strongSelf->_pendingAudioAttachment = audioAttachment;
                    
                    [strongSelf->_playAudioDisposable setDisposable:[[[TGBridgeAudioSignals audioForAttachment:audioAttachment conversationId:[strongSelf peerId] messageId:message.identifier] deliverOn:[SQueue mainQueue]] startWithNext:^(NSURL *url)
                    {
                        if (url == nil)
                            return;
                        
                        __strong TGNeoConversationController *strongSelf = weakSelf;
                        if (strongSelf == nil)
                            return;
                        
                        __strong TGNeoConversationRowController *strongConversationRow = weakConversationRow;
                        if (strongConversationRow != nil)
                            [strongConversationRow setProcessingState:false];
                        
                        strongSelf->_pendingAudioAttachment = nil;
                        
                        [strongSelf presentMediaPlayerControllerWithURL:url options:@{ WKMediaPlayerControllerOptionsAutoplayKey: @true } completion:^(BOOL didPlayToEnd, NSTimeInterval endTime, NSError *error) {}];
                    }]];
                }
            }
            else
            {
                [strongSelf->_remoteActionDisposable setDisposable:[[TGBridgeRemoteSignals openRemoteMessageWithPeerId:[strongSelf peerId] messageId:message.identifier type:0 autoPlay:true] startWithNext:nil]];
            }
        };
        
        TGNeoMessageType type = TGNeoMessageTypeGeneric;
        if ([self peerIsAnyGroup])
            type = TGNeoMessageTypeGroup;
        else if ([self peerIsChannel])
            type = TGNeoMessageTypeChannel;
        
        conversationRow.additionalPeers = _peerModels;
        [conversationRow updateWithMessage:message context:_context.context index:index type:type];
    }
    else if ([model isKindOfClass:[TGChatInfo class]])
    {
        TGChatInfo *chatInfo = (TGChatInfo *)model;
        
        TGNeoConversationStaticRowController *conversationRow = (TGNeoConversationStaticRowController *)controller;
        [conversationRow updateWithChatInfo:chatInfo];
    }
}

- (void)table:(WKInterfaceTable *)table didSelectRowAtIndexPath:(TGIndexPath *)indexPath
{
    TGBridgeMessage *message = _rowModels[indexPath.row];
    
    TGMessageViewControllerContext *context = nil;
    if ([self peerIsChannel] && ![self peerIsChannelGroup])
        context = [[TGMessageViewControllerContext alloc] initWithMessage:message channel:_chatModel];
    else
        context = [[TGMessageViewControllerContext alloc] initWithMessage:message peerId:[self peerId]];
    
    context.additionalPeers = _peerModels;
    
    [self pushControllerWithClass:[TGMessageViewController class] context:context];
}

- (Class)footerControllerClassForTable:(WKInterfaceTable *)table
{
    if ([self peerIsChannel] && ![self peerIsChannelGroup])
        return nil;
    
    return [TGConversationFooterController class];
}

- (void)table:(WKInterfaceTable *)table updateFooterController:(TGConversationFooterController *)controller
{
    __weak TGNeoConversationController *weakSelf = self;
    controller.animate = ^(void (^animations)(void))
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf animateWithDuration:0.3 animations:animations];
    };
    
    [controller setOptions:_footerOptions animated:!_dontAnimateFooterTransition];
    _dontAnimateFooterTransition = false;
    
    controller.stickerPressed = ^
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        TGStickersControllerContext *context = [[TGStickersControllerContext alloc] init];
        context.completionBlock = ^(TGBridgeDocumentMediaAttachment *sticker)
        {
            __strong TGNeoConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf sendMessageWithStickerAttachment:sticker];
        };
        [strongSelf presentControllerWithClass:[TGStickersController class] context:context];
    };
    controller.locationPressed = ^
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        TGLocationControllerContext *context = [[TGLocationControllerContext alloc] init];
        context.completionBlock = ^(TGBridgeLocationMediaAttachment *location)
        {
            __strong TGNeoConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf sendMessageWithLocationAttachment:location];
        };
        [strongSelf presentControllerWithClass:[TGLocationController class] context:context];
    };
    controller.voicePressed = ^
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        bool override = false;
#if TARGET_OS_SIMULATOR
        override = true;
#endif
        
        if (override || strongSelf->_context.context.micAccessAllowed)
        {
            [TGInputController presentAudioControllerForInterfaceController:strongSelf completion:^(int64_t uniqueId, int32_t duration, NSURL *url)
            {
                __strong TGNeoConversationController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf sendAudioWithUniqueId:uniqueId duration:duration url:url];
            }];
        }
        else
        {
            [strongSelf presentControllerWithClass:[TGAudioMicAlertController class] context:nil];
        }
    };
    controller.commandsPressed = ^
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf->_botReplyMarkup != nil)
        {
            TGBridgeBotReplyMarkup *replyMarkup = strongSelf->_botReplyMarkup;
            TGBotKeyboardControllerContext *context = [[TGBotKeyboardControllerContext alloc] init];
            context.replyMarkup = replyMarkup;
            context.completionBlock = ^(NSString *command)
            {
                __strong TGNeoConversationController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf sendMessageWithText:command replyToMessage:replyMarkup.message];
            };
            [strongSelf presentControllerWithClass:[TGBotKeyboardController class] context:context];
        }
        else
        {
            TGBotCommandControllerContext *context = [[TGBotCommandControllerContext alloc] init];
            context.commandListSignal = [strongSelf botCommandListSignal];
            context.context = strongSelf->_context.context;
            context.completionBlock = ^(NSString *command)
            {
                __strong TGNeoConversationController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf sendMessageWithText:command];
            };
            [strongSelf presentControllerWithClass:[TGBotCommandController class] context:context];
        }
    };
    controller.unblockPressed = ^
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_updateSettingsDisposable setDisposable:[[[TGBridgePeerSettingsSignals updateBlockStatusWithPeerId:[strongSelf peerId] blocked:false] deliverOn:[SQueue mainQueue]] startWithNext:nil completed:^
        {
            __strong TGNeoConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_blocked = false;
            [strongSelf reloadData];
        }]];
    };
    controller.replyPressed = ^
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [TGInputController presentInputControllerForInterfaceController:strongSelf suggestionsForText:[strongSelf _latestIncomingMessage].text completion:^(NSString *text)
        {
            [strongSelf sendMessageWithText:text];
        }];
    };
    controller.startPressed = ^
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf sendMessageWithText:@"/start"];
    };
    controller.restartPressed = ^
    {
        __strong TGNeoConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_updateSettingsDisposable setDisposable:[[[TGBridgePeerSettingsSignals updateBlockStatusWithPeerId:[strongSelf peerId] blocked:false] deliverOn:[SQueue mainQueue]] startWithNext:nil completed:^
        {
            __strong TGNeoConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
                                                                  
            strongSelf->_blocked = false;
            [strongSelf sendMessageWithText:@"/start"];
        }]];
    };
}

#pragma mark - 

+ (NSMutableArray *)reversedMessagesArray:(NSArray *)array
{
    if (array == nil)
        return nil;
    
    NSMutableArray *reversedArray = [[NSMutableArray alloc] init];
    for (id object in array)
        [reversedArray insertObject:object atIndex:0];
    
    return reversedArray;
}

+ (NSArray *)timestampedModelsArray:(NSArray *)models
{
    NSMutableArray *newModels = [[NSMutableArray alloc] init];
    TGChatTimestamp *lastTimestamp = nil;
    
    for (id model in models)
    {
        if ([model isKindOfClass:[TGChatTimestamp class]])
        {
            continue;
        }
        else if ([model isKindOfClass:[TGBridgeMessage class]])
        {
            TGBridgeMessage *message = (TGBridgeMessage *)model;
            
            TGChatTimestamp *timestamp = [TGDateUtils timestampForDateIfNeeded:message.date previousDate:lastTimestamp ? @(lastTimestamp.date) : nil];
            
            if (timestamp != nil)
            {
                lastTimestamp = timestamp;
                [newModels addObject:timestamp];
            }
        }
        
        [newModels addObject:model];
    }
    
    return newModels;
}

#pragma mark -

+ (NSString *)identifier
{
    return TGNeoConversationControllerIdentifier;
}

@end
