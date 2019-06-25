#import "TGUserInfoController.h"
#import "TGWatchCommon.h"
#import "TGStringUtils.h"

#import <WatchCommonWatch/WatchCommonWatch.h>
#import "TGBridgeBotSignals.h"
#import "TGBridgeUserInfoSignals.h"
#import "TGBridgePeerSettingsSignals.h"
#import "TGBridgeUserCache.h"
#import "TGUserHandle.h"

#import "TGTableDeltaUpdater.h"

#import "WKInterfaceTable+TGDataDrivenTable.h"
#import "TGInterfaceMenu.h"

#import "TGUserInfoHeaderController.h"
#import "TGUserHandleRowController.h"

#import "TGProfilePhotoController.h"
#import "TGNeoConversationController.h"

NSString *const TGUserInfoControllerIdentifier = @"TGUserInfoController";

@implementation TGUserInfoControllerContext

- (instancetype)initWithUser:(TGBridgeUser *)user
{
    self = [super init];
    if (self != nil)
    {
        _user = user;
    }
    return self;
}

- (instancetype)initWithUserId:(int32_t)userId
{
    self = [super init];
    if (self != nil)
    {
        _userId = userId;
    }
    return self;
}

- (instancetype)initWithChannel:(TGBridgeChat *)channel
{
    self = [super init];
    if (self != nil)
    {
        _channel = channel;
    }
    return self;
}

@end

@interface TGUserInfoController () <TGTableDataSource>
{
    SMetaDisposable *_userDisposable;
    SMetaDisposable *_botInfoDisposable;
    SMetaDisposable *_peerSettingsDisposable;
    SMetaDisposable *_updateSettingsDisposable;
    
    TGUserInfoControllerContext *_context;
    TGBridgeUser *_userModel;
    TGBridgeBotInfo *_botInfo;
    bool _muted;
    bool _blocked;
    
    TGBridgeChat *_channelModel;
    
    NSArray *_handleModels;
    NSArray *_currentHandleModels;
    
    TGInterfaceMenu *_menu;
}
@end

@implementation TGUserInfoController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _userDisposable = [[SMetaDisposable alloc] init];
        _peerSettingsDisposable = [[SMetaDisposable alloc] init];
        _updateSettingsDisposable = [[SMetaDisposable alloc] init];
    
        [self.table _setInitialHidden:true];
        self.table.tableDataSource = self;
    }
    return self;
}

- (void)dealloc
{
    [_userDisposable dispose];
    [_botInfoDisposable dispose];
    [_peerSettingsDisposable dispose];
    [_updateSettingsDisposable dispose];
}

- (void)configureWithContext:(TGUserInfoControllerContext *)context
{
    _context = context;
    
    if (context.channel != nil)
        [self configureWithChannelContext:context];
    else
        [self configureWithUserContext:context];
}

- (void)configureWithChannelContext:(TGUserInfoControllerContext *)context
{
    _channelModel = context.channel;
    
    self.title = _channelModel.isChannelGroup ? TGLocalized(@"Watch.GroupInfo.Title") : TGLocalized(@"Watch.ChannelInfo.Title");
    
    [self updateChannelHandles];
    
    __weak TGUserInfoController *weakSelf = self;
    [self performInterfaceUpdate:^(bool animated)
    {
        __strong TGUserInfoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf reloadData];
    }];
    
    [self setupPeerSettingsWithId:_channelModel.identifier];
}

- (void)configureWithUserContext:(TGUserInfoControllerContext *)context
{
    self.title = TGLocalized(@"Watch.UserInfo.Title");
    
    int32_t userId = (_context.user != nil) ? (int32_t)_context.user.identifier : _context.userId;
    SSignal *remoteUserSignal = [TGBridgeUserInfoSignals userInfoWithUserId:userId];
    
    SSignal *userSignal = nil;
    
    TGBridgeUser *cachedUser = [[TGBridgeUserCache instance] userWithId:userId];
    if (cachedUser == nil)
        cachedUser = _context.user;
    
    if (cachedUser != nil)
        userSignal = [[SSignal single:cachedUser] then:remoteUserSignal];
    else
        userSignal = remoteUserSignal;
    
    __weak TGUserInfoController *weakSelf = self;
    [_userDisposable setDisposable:[[userSignal deliverOn:[SQueue mainQueue]] startWithNext:^(TGBridgeUser *user)
    {
        __strong TGUserInfoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_userModel = user;
        [[TGBridgeUserCache instance] storeUser:user];
        
        if ([strongSelf _userIsBot] && strongSelf->_botInfo == nil)
        {
            strongSelf->_botInfoDisposable = [[SMetaDisposable alloc] init];
            [strongSelf->_botInfoDisposable setDisposable:[[TGBridgeBotSignals botInfoForUserId:user.identifier] startWithNext:^(TGBridgeBotInfo *botInfo)
            {
                __strong TGUserInfoController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;

                strongSelf->_botInfo = botInfo;
                
                [strongSelf updateUserHandles];
                
                [strongSelf performInterfaceUpdate:^(bool animated)
                {
                    __strong TGUserInfoController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    [strongSelf reloadData];
                }];
            }]];
        }
      
        [strongSelf updateUserHandles];
        
        [strongSelf performInterfaceUpdate:^(bool animated)
        {
            __strong TGUserInfoController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf reloadData];
        }];
    }]];
    
    [self setupPeerSettingsWithId:userId];
}

- (void)setupPeerSettingsWithId:(int64_t)peerId
{
    __weak TGUserInfoController *weakSelf = self;
    [_peerSettingsDisposable setDisposable:[[[TGBridgePeerSettingsSignals peerSettingsWithPeerId:peerId] deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *next)
    {
        __strong TGUserInfoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        bool blocked = [next[@"blocked"] boolValue];
        bool muted = [next[@"muted"] boolValue];
        
        strongSelf->_blocked = blocked;
        strongSelf->_muted = muted;
        
        [strongSelf performInterfaceUpdate:^(bool animated)
        {
            __strong TGUserInfoController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf reloadData];
        }];
    }]];
}

- (void)updateUserHandles
{
    NSMutableArray *handles = [[NSMutableArray alloc] init];
    if (_userModel.phoneNumber.length > 0)
    {
        [handles addObject:[[TGUserHandle alloc] initWithHandle:_userModel.prettyPhoneNumber type:TGLocalized(@"UserInfo.GenericPhoneLabel") handleType:TGUserHandleTypePhone data:_userModel.phoneNumber]];
    }
    if (_userModel.userName.length > 0)
    {
        [handles addObject:[[TGUserHandle alloc] initWithHandle:[NSString stringWithFormat:@"@%@", self->_userModel.userName] type:TGLocalized(@"Profile.Username") handleType:TGUserHandleTypeUndefined data:nil]];
    }
    if (_userModel.about.length > 0)
    {
        [handles addObject:[[TGUserHandle alloc] initWithHandle:_userModel.about type:TGLocalized(@"Profile.BotInfo") handleType:TGUserHandleTypeDescription data:nil]];
    }
    
    _handleModels = handles;
}

- (void)updateChannelHandles
{
    NSMutableArray *handles = [[NSMutableArray alloc] init];
    if (_channelModel.userName.length > 0)
    {
        [handles addObject:[[TGUserHandle alloc] initWithHandle:[NSString stringWithFormat:@"t.me/%@", self->_channelModel.userName] type:TGLocalized(@"Channel.LinkItem") handleType:TGUserHandleTypeUndefined data:nil]];
    }
    if (_channelModel.about.length > 0)
    {
        [handles addObject:[[TGUserHandle alloc] initWithHandle:_channelModel.about type:TGLocalized(@"Channel.AboutItem") handleType:TGUserHandleTypeDescription data:nil]];
    }
    
    _handleModels = handles;
}

- (void)reloadData
{
    NSArray *currentHandles = _currentHandleModels;
    _currentHandleModels = _handleModels;
    
    self.activityIndicator.hidden = true;
    
    NSInteger numberOfRows = [self numberOfRowsInTable:self.table section:0];
    if (self.table.numberOfRows == numberOfRows + 1)
    {
        [self.table reloadHeader];
        
        NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
        for (NSInteger i = 0; i < numberOfRows; i++)
            [indexPaths addObject:[TGIndexPath indexPathForRow:i inSection:0]];
        
        [self.table reloadRowsAtIndexPaths:indexPaths];
    }
    else
    {
        if (self.table.hidden)
        {
            [self.table reloadData];
        }
        else
        {
            [TGTableDeltaUpdater updateTable:self.table oldData:currentHandles newData:_currentHandleModels controllerClassForIndexPath:^Class(TGIndexPath *indexPath)
            {
                return nil;
            }];
        }
    }
    
    [self updateMenuItems];
    
    self.table.hidden = false;
}

- (void)willActivate
{
    [super willActivate];
    
    [self.table notifyVisiblityChange];
}

- (void)didDeactivate
{
    [super didDeactivate];
}

#pragma mark -

- (void)updateMenuItems
{
    if (_context.userId == _context.context.userId) {
        return;
    }
    
    [_menu clearItems];
    
    if (_menu == nil)
        _menu = [[TGInterfaceMenu alloc] initForInterfaceController:self];
    
    __weak TGUserInfoController *weakSelf = self;
    
    NSMutableArray *menuItems = [[NSMutableArray alloc] init];
    
    bool muted = _muted;
    bool blocked = _blocked;
    
    bool muteForever = _channelModel.isChannelGroup;
    int32_t muteFor = muteForever ? INT_MAX : 1;
    NSString *muteTitle = muteForever ? TGLocalized(@"Watch.UserInfo.MuteTitle") : [NSString stringWithFormat:TGLocalized([TGStringUtils integerValueFormat:@"Watch.UserInfo.Mute_" value:muteFor]), muteFor];
    
    TGInterfaceMenuItem *muteItem = [[TGInterfaceMenuItem alloc] initWithItemIcon:muted ? WKMenuItemIconSpeaker : WKMenuItemIconMute title:muted ? TGLocalized(@"Watch.UserInfo.Unmute") : muteTitle actionBlock:^(TGInterfaceController *controller, TGInterfaceMenuItem *sender)
    {
        __strong TGUserInfoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_updateSettingsDisposable setDisposable:[[TGBridgePeerSettingsSignals toggleMutedWithPeerId:strongSelf->_userModel.identifier] startWithNext:nil completed:^
        {
            __strong TGUserInfoController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_muted = !muted;
            [strongSelf updateMenuItems];
        }]];
    }];
    [menuItems addObject:muteItem];
    
    if (_channelModel == nil)
    {
        TGInterfaceMenuItem *blockItem = [[TGInterfaceMenuItem alloc] initWithItemIcon:WKMenuItemIconBlock title:blocked ? TGLocalized(@"Watch.UserInfo.Unblock") : TGLocalized(@"Watch.UserInfo.Block") actionBlock:^(TGInterfaceController *controller, TGInterfaceMenuItem *sender)
        {
            __strong TGUserInfoController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_updateSettingsDisposable setDisposable:[[TGBridgePeerSettingsSignals updateBlockStatusWithPeerId:strongSelf->_userModel.identifier blocked:!blocked] startWithNext:nil completed:^
            {
                __strong TGUserInfoController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf->_blocked = !blocked;
                [strongSelf updateMenuItems];
            }]];
        }];
        [menuItems addObject:blockItem];
    }
    
    if (!_context.disallowCompose)
    {
        TGInterfaceMenuItem *composeItem = [[TGInterfaceMenuItem alloc] initWithImageNamed:@"Compose" title:TGLocalized(@"Watch.UserInfo.SendMessage") actionBlock:^(TGInterfaceController *controller, TGInterfaceMenuItem *sender)
        {
            __strong TGUserInfoController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            TGNeoConversationControllerContext *context = [[TGNeoConversationControllerContext alloc] initWithPeerId:strongSelf->_userModel.identifier];
            
            [strongSelf pushControllerWithClass:[TGNeoConversationController class] context:context];
        }];
        [menuItems addObject:composeItem];
    }

    [_menu addItems:menuItems];
}

#pragma mark - 

- (Class)headerControllerClassForTable:(WKInterfaceTable *)table
{
    return [TGUserInfoHeaderController class];
}

- (void)table:(WKInterfaceTable *)table updateHeaderController:(TGUserInfoHeaderController *)controller
{
    __weak TGUserInfoController *weakSelf = self;
    controller.isVisible = ^bool
    {
        __strong TGUserInfoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return strongSelf.isVisible;
    };
    controller.avatarPressed = ^
    {
        __strong TGUserInfoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        int64_t identifier = 0;
        NSString *url = nil;
        if (strongSelf->_userModel != nil) {
            identifier = strongSelf->_userModel.identifier;
            url = strongSelf->_userModel.photoSmall;
        }
        else if (strongSelf->_channelModel != nil) {
            identifier = strongSelf->_channelModel.identifier;
            url = strongSelf->_channelModel.groupPhotoSmall;
        }
        
        if (url != nil)
        {
            TGProfilePhotoControllerContext *context = [[TGProfilePhotoControllerContext alloc] initWithIdentifier:identifier imageUrl:url];
                [strongSelf pushControllerWithClass:[TGProfilePhotoController class] context:context];
        }
    };
    
    if (_userModel != nil)
        [controller updateWithUser:_userModel context:_context.context];
    else
        [controller updateWithChannel:_channelModel];
}

- (NSUInteger)numberOfRowsInTable:(WKInterfaceTable *)table section:(NSUInteger)section
{
    return _currentHandleModels.count;
}

- (Class)table:(WKInterfaceTable *)table rowControllerClassAtIndexPath:(TGIndexPath *)indexPath
{
    TGUserHandle *userHandle = _currentHandleModels[indexPath.row];
    switch (userHandle.handleType)
    {
        case TGUserHandleTypePhone:
            return [TGUserHandleActiveRowController class];
            break;
            
        default:
            return [TGUserHandleRowController class];
    }
}

- (void)table:(WKInterfaceTable *)table updateRowController:(TGUserHandleRowController *)controller forIndexPath:(TGIndexPath *)indexPath
{
    TGUserHandle *userHandle = _currentHandleModels[indexPath.row];
    [controller updateWithUserHandle:userHandle];
}

- (void)table:(WKInterfaceTable *)table didSelectRowAtIndexPath:(TGIndexPath *)indexPath
{
    TGUserHandle *userHandle = _currentHandleModels[indexPath.row];
    switch (userHandle.handleType)
    {
        case TGUserHandleTypePhone:
            [[WKExtension sharedExtension] openSystemURL:[NSURL URLWithString:[NSString stringWithFormat:@"tel://%@", userHandle.data]]];
            break;
            
        default:
            break;
    }
}

- (bool)_userHasPhone
{
    return (_userModel.phoneNumber.length > 0);
}

- (bool)_userHasUsername
{
    return (_userModel.userName.length > 0);
}

- (bool)_userIsBot
{
    return (_userModel.kind != TGBridgeUserKindGeneric);
}

- (bool)_botHasDescription
{
    return (_botInfo.shortDescription.length > 0);
}

#pragma mark - 

+ (NSString *)identifier
{
    return TGUserInfoControllerIdentifier;
}

@end
