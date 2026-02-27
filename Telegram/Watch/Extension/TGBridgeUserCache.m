#import "TGBridgeUserCache.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGFileCache.h"

#import <libkern/OSAtomic.h>

@interface TGBridgeUserCache ()
{
    NSMutableDictionary *_userByUid;
    OSSpinLock _userByUidLock;
    
    NSMutableDictionary *_botInfoByUid;
    OSSpinLock _botInfoByUidLock;
    
    TGFileCache *_fileCache;
}
@end

@implementation TGBridgeUserCache

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _userByUid = [[NSMutableDictionary alloc] init];
        _botInfoByUid = [[NSMutableDictionary alloc] init];
        
        _fileCache = [[TGFileCache alloc] initWithName:@"users" useMemoryCache:false];
    }
    return self;
}

- (TGBridgeUser *)userWithId:(int64_t)userId
{
    __block TGBridgeUser *user = nil;
    
    OSSpinLockLock(&_userByUidLock);
    user = _userByUid[@(userId)];
    OSSpinLockUnlock(&_userByUidLock);
    
    return user;
}

- (NSDictionary *)usersWithIds:(NSArray<NSNumber *> *)indexSet
{
    NSMutableDictionary *users = [[NSMutableDictionary alloc] init];
    NSMutableSet<NSNumber *> *neededUsers = [indexSet mutableCopy];
    
    NSMutableSet<NSNumber *> *foundUsers = [[NSMutableSet alloc] init];
    
    OSSpinLockLock(&_userByUidLock);
    for (NSNumber *nId in neededUsers) {
        int64_t index = [nId longLongValue];
        TGBridgeUser *user = _userByUid[@(index)];
        if (user != nil)
        {
            users[@(index)] = user;
            [foundUsers addObject:@(index)];
        }
    }
    OSSpinLockUnlock(&_userByUidLock);
    
    for (NSNumber *nId in foundUsers) {
        [neededUsers removeObject:nId];
    }
    
    return users;
}

- (void)storeUser:(TGBridgeUser *)user
{
    if (user == nil)
        return;
    
    [self storeUsers:@[ user ]];
}

- (void)storeUsers:(NSArray *)users
{
    OSSpinLockLock(&_userByUidLock);
    for (id peer in users)
    {
        if ([peer isKindOfClass:[TGBridgeUser class]])
            _userByUid[@(((TGBridgeUser *)peer).identifier)] = peer;
    }
    OSSpinLockUnlock(&_userByUidLock);
}

- (NSArray *)applyUserChanges:(NSArray *)userChanges
{
    NSMutableArray *missedUserIds = [[NSMutableArray alloc] init];
    NSMutableArray *updatedUsers = [[NSMutableArray alloc] init];
    for (TGBridgeUserChange *change in userChanges)
    {
        TGBridgeUser *user = [self userWithId:change.userIdentifier];
        if (user != nil)
        {
            TGBridgeUser *updatedUser = [user userByApplyingChange:change];
            [updatedUsers addObject:updatedUser];
        }
        else
        {
            [missedUserIds addObject:@(change.userIdentifier)];
        }
    }
    
    [self storeUsers:updatedUsers];
    
    if (missedUserIds.count == 0)
        return nil;
    
    return missedUserIds;
}

- (TGBridgeBotInfo *)botInfoForUserId:(int32_t)userId
{
    __block TGBridgeBotInfo *botInfo = nil;
    
    OSSpinLockLock(&_botInfoByUidLock);
    botInfo = _botInfoByUid[@(userId)];
    OSSpinLockUnlock(&_botInfoByUidLock);
    
    if (botInfo == nil)
    {
        [_fileCache fetchDataForKey:[NSString stringWithFormat:@"botInfo-%d", userId] synchronous:true unserializeBlock:^id(NSData *data)
        {
            id object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            if ([object isKindOfClass:[TGBridgeBotInfo class]])
                return object;
             
            return nil;
        } completion:^(TGBridgeBotInfo *result)
        {
            if (result != nil)
            {
                botInfo = result;
                OSSpinLockLock(&_botInfoByUidLock);
                _botInfoByUid[@(userId)] = botInfo;
                OSSpinLockUnlock(&_botInfoByUidLock);
            }
        }];
    }
    
    return botInfo;
}

- (void)storeBotInfo:(TGBridgeBotInfo *)botInfo forUserId:(int32_t)userId
{
    OSSpinLockLock(&_botInfoByUidLock);
    _botInfoByUid[@(userId)] = botInfo;
    
    [_fileCache cacheData:botInfo key:[NSString stringWithFormat:@"botInfo-%d", userId] synchronous:true serializeBlock:^NSData *(NSObject<NSCoding> *object)
    {
        return [NSKeyedArchiver archivedDataWithRootObject:object];
    } completion:nil];
    OSSpinLockUnlock(&_botInfoByUidLock);
}

+ (instancetype)instance
{
    static dispatch_once_t onceToken;
    static TGBridgeUserCache *userCache;
    dispatch_once(&onceToken, ^
    {
        userCache = [[TGBridgeUserCache alloc] init];
    });
    return userCache;
}

@end
