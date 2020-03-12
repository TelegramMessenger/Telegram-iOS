#import "TGGroupInfoController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"

#import "TGStringUtils.h"

#import "TGBridgeConversationSignals.h"
#import "TGBridgePeerSettingsSignals.h"

#import "WKInterfaceTable+TGDataDrivenTable.h"
#import "TGTableDeltaUpdater.h"
#import "TGInterfaceMenu.h"

#import "TGGroupInfoHeaderController.h"
#import "TGGroupInfoFooterController.h"
#import "TGUserRowController.h"

#import "TGInputController.h"
#import "TGUserInfoController.h"
#import "TGContactsController.h"
#import "TGProfilePhotoController.h"

NSString *const TGGroupInfoControllerIdentifier = @"TGGroupInfoController";

@implementation TGGroupInfoControllerContext

- (instancetype)initWithGroupChat:(TGBridgeChat *)groupChat
{
    self = [super init];
    if (self != nil)
    {
        _groupChat = groupChat;
    }
    return self;
}

@end

@interface TGGroupInfoController () <TGTableDataSource>
{
    SMetaDisposable *_chatDisposable;
    SMetaDisposable *_peerSettingsDisposable;
    SMetaDisposable *_updateSettingsDisposable;
    
    TGInterfaceMenu *_menu;
    
    TGGroupInfoControllerContext *_context;
    TGBridgeChat *_chatModel;
    NSDictionary *_userModels;
    NSArray *_participantsModels;
    NSArray *_currentParticipantsModels;
    bool _muted;
    
    NSDictionary *_preferredParticipantsOrder;
}
@end

@implementation TGGroupInfoController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _chatDisposable = [[SMetaDisposable alloc] init];
        _peerSettingsDisposable = [[SMetaDisposable alloc] init];
        _updateSettingsDisposable = [[SMetaDisposable alloc] init];
        
        [self.table _setInitialHidden:true];
        self.table.tableDataSource = self;
    }
    return self;
}

- (void)dealloc
{
    [_chatDisposable dispose];
    [_peerSettingsDisposable dispose];
    [_updateSettingsDisposable dispose];
}

- (void)configureWithContext:(TGGroupInfoControllerContext *)context
{
    _context = context;
    
    self.title = TGLocalized(@"Watch.GroupInfo.Title");
    
    __weak TGGroupInfoController *weakSelf = self;
    [_chatDisposable setDisposable:[[[TGBridgeConversationSignals conversationWithPeerId:_context.groupChat.identifier] deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *models)
    {
        __strong TGGroupInfoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_chatModel = models[TGBridgeChatKey];
        strongSelf->_userModels = models[TGBridgeUsersDictionaryKey];
        
        NSMutableArray *participantsModels = [[NSMutableArray alloc] init];
        for (NSNumber *uid in strongSelf->_chatModel.participants)
        {
            TGBridgeUser *user = strongSelf->_userModels[uid];
            if (user != nil)
                [participantsModels addObject:user];
        }
        
        participantsModels = [TGGroupInfoController sortedParticipantsList:participantsModels preferredOrder:strongSelf->_preferredParticipantsOrder ownUid:strongSelf->_context.context.userId];
        strongSelf->_preferredParticipantsOrder = [TGGroupInfoController participantsOrderForList:participantsModels];
        
        strongSelf->_participantsModels = participantsModels;
        
        [strongSelf performInterfaceUpdate:^(bool animated)
        {
            strongSelf.activityIndicator.hidden = true;
            strongSelf.table.hidden = false;
            
            NSArray *currentParticipantsModels = strongSelf->_currentParticipantsModels;
            bool initial = (currentParticipantsModels == 0);
            
            strongSelf->_currentParticipantsModels = strongSelf->_participantsModels;
            
            if (animated && !initial)
            {
                [TGTableDeltaUpdater updateTable:strongSelf.table oldData:currentParticipantsModels newData:strongSelf->_currentParticipantsModels controllerClassForIndexPath:^Class(TGIndexPath *indexPath)
                {
                    return [strongSelf table:strongSelf->_table rowControllerClassAtIndexPath:indexPath];
                }];
                
                [strongSelf.table reloadHeader];
                [strongSelf.table reloadFooter];
            }
            else
            {
                [strongSelf.table reloadData];
            }
        }];
        
    } error:^(id error)
    {
        
    } completed:^
    {
        
    }]];
    
    [_peerSettingsDisposable setDisposable:[[[TGBridgePeerSettingsSignals peerSettingsWithPeerId:_context.groupChat.identifier] deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *next)
    {
        __strong TGGroupInfoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        bool muted = [next[@"muted"] boolValue];
        
        if (strongSelf->_menu == nil || muted != strongSelf->_muted)
        {
            strongSelf->_muted = muted;
            
            [strongSelf performInterfaceUpdate:^(bool animated)
            {
                [strongSelf updateMenuItemsMuted:strongSelf->_muted];
            }];
        }
    }]];
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

- (void)updateMenuItemsMuted:(bool)muted
{
    [_menu clearItems];
    
    if (_menu == nil)
        _menu = [[TGInterfaceMenu alloc] initForInterfaceController:self];
    
    __weak TGGroupInfoController *weakSelf = self;
    
    NSMutableArray *menuItems = [[NSMutableArray alloc] init];

    bool muteForever = true;
    int32_t muteFor = muteForever ? INT_MAX : 1;
    NSString *muteTitle = muteForever ? TGLocalized(@"Watch.UserInfo.MuteTitle") : [NSString stringWithFormat:TGLocalized([TGStringUtils integerValueFormat:@"Watch.UserInfo.Mute_" value:muteFor]), muteFor];
    
    TGInterfaceMenuItem *muteItem = [[TGInterfaceMenuItem alloc] initWithItemIcon:muted ? WKMenuItemIconSpeaker : WKMenuItemIconMute title:muted ? TGLocalized(@"Watch.UserInfo.Unmute") : muteTitle actionBlock:^(TGInterfaceController *controller, TGInterfaceMenuItem *sender)
    {
        __strong TGGroupInfoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_updateSettingsDisposable setDisposable:[[TGBridgePeerSettingsSignals toggleMutedWithPeerId:strongSelf->_context.groupChat.identifier] startWithNext:nil completed:^
        {
            __strong TGGroupInfoController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_muted = !muted;
            [strongSelf updateMenuItemsMuted:strongSelf->_muted];
        }]];
    }];
    [menuItems addObject:muteItem];
    
    [_menu addItems:menuItems];
}

#pragma mark - 

- (Class)headerControllerClassForTable:(WKInterfaceTable *)table
{
    return [TGGroupInfoHeaderController class];
}

- (void)table:(WKInterfaceTable *)table updateHeaderController:(TGGroupInfoHeaderController *)controller
{
    __weak TGGroupInfoController *weakSelf = self;
    controller.isVisible = ^bool
    {
        __strong TGGroupInfoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return strongSelf.isVisible;
    };
    controller.avatarPressed = ^
    {
        __strong TGGroupInfoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        TGProfilePhotoControllerContext *context = [[TGProfilePhotoControllerContext alloc] initWithIdentifier:strongSelf->_chatModel.identifier imageUrl:strongSelf->_chatModel.groupPhotoSmall];
        [strongSelf pushControllerWithClass:[TGProfilePhotoController class] context:context];
    };
    
    [controller updateWithGroupChat:_chatModel users:_userModels context:_context.context];
}

- (void)table:(WKInterfaceTable *)table updateFooterController:(TGGroupInfoFooterController *)controller
{

}

- (Class)table:(WKInterfaceTable *)table rowControllerClassAtIndexPath:(NSIndexPath *)indexPath
{
    return [TGUserRowController class];
}

- (NSUInteger)numberOfRowsInTable:(WKInterfaceTable *)table section:(NSUInteger)section
{
    return _currentParticipantsModels.count;
}

- (void)table:(WKInterfaceTable *)table updateRowController:(TGUserRowController *)controller forIndexPath:(TGIndexPath *)indexPath
{
    __weak TGGroupInfoController *weakSelf = self;
    controller.isVisible = ^bool
    {
        __strong TGGroupInfoController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return strongSelf.isVisible;
    };
    [controller updateWithUser:_currentParticipantsModels[indexPath.row] context:_context.context];
}

- (id<TGInterfaceContext>)contextForSegueWithIdentifer:(NSString *)segueIdentifier table:(WKInterfaceTable *)table indexPath:(TGIndexPath *)indexPath
{
    return [[TGUserInfoControllerContext alloc] initWithUser:_currentParticipantsModels[indexPath.row]];
}

+ (NSMutableArray *)sortedParticipantsList:(NSMutableArray *)list preferredOrder:(NSDictionary *)preferredOrder ownUid:(int32_t)ownUid
{
    NSMutableArray *resultList = [list mutableCopy];
    
    [resultList sortUsingComparator:^NSComparisonResult(TGBridgeUser *user1, TGBridgeUser *user2)
    {
        if (user1.identifier == ownUid)
            return NSOrderedAscending;
        else if (user2.identifier == ownUid)
            return NSOrderedDescending;
        
        NSNumber *order1 = preferredOrder[@(user1.identifier)];
        NSNumber *order2 = preferredOrder[@(user2.identifier)];
        
        if (order1 != nil && order2 != nil)
            return order1.integerValue < order2.integerValue ? NSOrderedAscending : NSOrderedDescending;
        
        if (user1.online != user2.online)
            return user1.online ? NSOrderedAscending : NSOrderedDescending;
        
        if ((user1.lastSeen < 0) != (user2.lastSeen < 0))
            return user1.lastSeen >= 0 ? NSOrderedAscending : NSOrderedDescending;
        
        if (user1.online || user1.lastSeen < 0)
            return user1.identifier < user2.identifier ? NSOrderedAscending : NSOrderedDescending;
        
        return user1.lastSeen > user2.lastSeen ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    return resultList;
}

+ (NSDictionary *)participantsOrderForList:(NSArray *)list
{
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    NSInteger i = 0;
    for (TGBridgeUser *user in list)
    {
        dictionary[@(user.identifier)] = @(i);
        i++;
    }
    
    return dictionary;
}

#pragma mark -

+ (NSString *)identifier
{
    return TGGroupInfoControllerIdentifier;
}

@end
