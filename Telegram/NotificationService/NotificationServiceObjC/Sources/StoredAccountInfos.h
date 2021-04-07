#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AccountNotificationKey: NSObject

@property (nonatomic, strong, readonly) NSData *keyId;
@property (nonatomic, strong, readonly) NSData *data;

@end

@interface AccountDatacenterKey: NSObject

@property (nonatomic, readonly) int64_t keyId;
@property (nonatomic, strong, readonly) NSData *data;

@end

@interface AccountDatacenterAddress: NSObject

@property (nonatomic, strong, readonly) NSString *host;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, readonly) bool isMedia;
@property (nonatomic, strong, readonly) NSData * _Nullable secret;

@end

@interface AccountDatacenterInfo: NSObject

@property (nonatomic, strong, readonly) AccountDatacenterKey *masterKey;
@property (nonatomic, strong, readonly) AccountDatacenterKey *ephemeralMainKey;
@property (nonatomic, strong, readonly) AccountDatacenterKey *ephemeralMediaKey;
@property (nonatomic, strong, readonly) NSArray<AccountDatacenterAddress *> *addressList;

@end

@interface AccountProxyConnection: NSObject

@property (nonatomic, strong, readonly) NSString *host;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, strong) NSString * _Nullable username;
@property (nonatomic, strong) NSString * _Nullable password;
@property (nonatomic, strong) NSData * _Nullable secret;

@end

@interface StoredAccountInfo : NSObject

@property (nonatomic, readonly) int64_t accountId;
@property (nonatomic, readonly) int32_t primaryId;
@property (nonatomic, readonly) bool isTestingEnvironment;
@property (nonatomic, strong, readonly) NSString *peerName;
@property (nonatomic, strong, readonly) NSDictionary<NSNumber *, AccountDatacenterInfo *> *datacenters;
@property (nonatomic, strong, readonly) AccountNotificationKey *notificationKey;

@end

@interface StoredAccountInfos : NSObject

@property (nonatomic, strong, readonly) AccountProxyConnection * _Nullable proxy;
@property (nonatomic, strong, readonly) NSArray<StoredAccountInfo *> *accounts;

+ (StoredAccountInfos * _Nullable)loadFromPath:(NSString *)path;

@end

NSDictionary * _Nullable decryptedNotificationPayload(NSArray<StoredAccountInfo *> *accounts, NSData *data, int *selectedAccountIndex);

NS_ASSUME_NONNULL_END
