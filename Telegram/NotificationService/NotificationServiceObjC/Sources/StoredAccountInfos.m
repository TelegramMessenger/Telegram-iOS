#import "StoredAccountInfos.h"

#import <MTProtoKit/MTProtoKit.h>

#import <CommonCrypto/CommonDigest.h>

@implementation AccountNotificationKey

- (instancetype)initWithKeyId:(NSData *)keyId data:(NSData *)data {
    self = [super init];
    if (self != nil) {
        _keyId = keyId;
        _data = data;
    }
    return self;
}

+ (instancetype _Nullable)parse:(NSDictionary *)dict {
    NSString *keyIdString = dict[@"id"];
    NSData *keyId = nil;
    if ([keyIdString isKindOfClass:[NSString class]]) {
        keyId = [[NSData alloc] initWithBase64EncodedString:keyIdString options:0];
    }
    if (keyId == nil) {
        return nil;
    }
    
    NSString *dataString = dict[@"data"];
    NSData *data = nil;
    if ([dataString isKindOfClass:[NSString class]]) {
        data = [[NSData alloc] initWithBase64EncodedString:dataString options:0];
    }
    if (data == nil) {
        return nil;
    }
    
    return [[AccountNotificationKey alloc] initWithKeyId:keyId data:data];
}

@end

@implementation AccountDatacenterKey

- (instancetype)initWithKeyId:(int64_t)keyId data:(NSData *)data {
    self = [super init];
    if (self != nil) {
        _keyId = keyId;
        _data = data;
    }
    return self;
}

+ (instancetype _Nullable)parse:(NSDictionary *)dict {
    NSNumber *keyIdNumber = dict[@"id"];
    if (![keyIdNumber isKindOfClass:[NSNumber class]]) {
        return nil;
    }
    int64_t keyId = [keyIdNumber longLongValue];
    
    NSString *dataString = dict[@"data"];
    NSData *data = nil;
    if ([dataString isKindOfClass:[NSString class]]) {
        data = [[NSData alloc] initWithBase64EncodedString:dataString options:0];
    }
    if (data == nil) {
        return nil;
    }
    
    return [[AccountDatacenterKey alloc] initWithKeyId:keyId data:data];
}

@end

@implementation AccountDatacenterAddress

- (instancetype)initWithHost:(NSString *)host port:(int32_t)port isMedia:(bool)isMedia secret:(NSData * _Nullable)secret {
    self = [super init];
    if (self != nil) {
        _host = host;
        _port = port;
        _isMedia = isMedia;
        _secret = secret;
    }
    return self;
}

+ (instancetype _Nullable)parse:(NSDictionary *)dict {
    NSString *hostString = dict[@"host"];
    if (![hostString isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *host = hostString;
    
    NSNumber *portNumber = dict[@"port"];
    if (![portNumber isKindOfClass:[NSNumber class]]) {
        return nil;
    }
    int32_t port = [portNumber intValue];
    
    NSNumber *isMediaNumber = dict[@"isMedia"];
    if (![isMediaNumber isKindOfClass:[NSNumber class]]) {
        return nil;
    }
    bool isMedia = [isMediaNumber intValue] != 0;
    
    NSString *secretString = dict[@"secret"];
    NSData *secret = nil;
    if ([secretString isKindOfClass:[NSString class]]) {
        secret = [[NSData alloc] initWithBase64EncodedString:secretString options:0];
    }
    
    return [[AccountDatacenterAddress alloc] initWithHost:host port:port isMedia:isMedia secret:secret];
}

@end

@implementation AccountDatacenterInfo

- (instancetype)initWithMasterKey:(AccountDatacenterKey *)masterKey ephemeralMainKey:(AccountDatacenterKey * _Nullable)ephemeralMainKey ephemeralMediaKey:(AccountDatacenterKey * _Nullable)ephemeralMediaKey addressList:(NSArray<AccountDatacenterAddress *> *)addressList {
    self = [super init];
    if (self != nil) {
        _masterKey = masterKey;
        _ephemeralMainKey = ephemeralMainKey;
        _ephemeralMediaKey = ephemeralMediaKey;
        _addressList = addressList;
    }
    return self;
}

+ (instancetype _Nullable)parse:(NSDictionary *)dict {
    NSDictionary *masterKeyDict = dict[@"masterKey"];
    if (![masterKeyDict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    AccountDatacenterKey *masterKey = [AccountDatacenterKey parse:masterKeyDict];
    if (masterKey == nil) {
        return nil;
    }
    
    NSDictionary *ephemeralMainKeyDict = dict[@"ephemeralMainKey"];
    AccountDatacenterKey *ephemeralMainKey = nil;
    if ([ephemeralMainKeyDict isKindOfClass:[NSDictionary class]]) {
        ephemeralMainKey = [AccountDatacenterKey parse:ephemeralMainKeyDict];
    }
    
    NSDictionary *ephemeralMediaKeyDict = dict[@"ephemeralMediaKey"];
    AccountDatacenterKey *ephemeralMediaKey = nil;
    if ([ephemeralMediaKeyDict isKindOfClass:[NSDictionary class]]) {
        ephemeralMediaKey = [AccountDatacenterKey parse:ephemeralMediaKeyDict];
    }
    
    NSArray *addressListArray = dict[@"addressList"];
    if (![addressListArray isKindOfClass:[NSArray class]]) {
        return nil;
    }
    
    NSMutableArray<AccountDatacenterAddress *> *addressList = [[NSMutableArray alloc] init];
    for (NSDictionary *addressListItem in addressListArray) {
        if (![addressListItem isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        AccountDatacenterAddress *address = [AccountDatacenterAddress parse:addressListItem];
        if (address == nil) {
            return nil;
        }
        [addressList addObject:address];
    }
    
    return [[AccountDatacenterInfo alloc] initWithMasterKey:masterKey ephemeralMainKey:ephemeralMainKey ephemeralMediaKey:ephemeralMediaKey addressList:addressList];
}

@end

@implementation AccountProxyConnection

- (instancetype)initWithHost:(NSString *)host port:(int32_t)port username:(NSString * _Nullable)username password:(NSString * _Nullable)password secret:(NSData * _Nullable)secret {
    self = [super init];
    if (self != nil) {
        _host = host;
        _port = port;
        username = _username;
        password = _password;
        secret = _secret;
    }
    return self;
}

+ (instancetype _Nullable)parse:(NSDictionary *)dict {
    NSString *hostString = dict[@"host"];
    if (![hostString isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *host = hostString;
    
    NSNumber *portNumber = dict[@"port"];
    if (![portNumber isKindOfClass:[NSNumber class]]) {
        return nil;
    }
    
    int32_t port = [portNumber intValue];
    
    NSString *usernameString = dict[@"username"];
    NSString *username = nil;
    if ([usernameString isKindOfClass:[NSString class]]) {
        username = usernameString;
    }
    
    NSString *passwordString = dict[@"password"];
    NSString *password = nil;
    if ([passwordString isKindOfClass:[NSString class]]) {
        password = passwordString;
    }
    
    NSString *secretString = dict[@"secret"];
    NSData *secret = nil;
    if ([secretString isKindOfClass:[NSString class]]) {
        secret = [[NSData alloc] initWithBase64EncodedString:secretString options:0];
    }
    
    return [[AccountProxyConnection alloc] initWithHost:host port:port username:username password:password secret:secret];
}

@end

@implementation StoredAccountInfo

- (instancetype)initWithAccountId:(int64_t)accountId primaryId:(int32_t)primaryId isTestingEnvironment:(bool)isTestingEnvironment peerName:(NSString *)peerName datacenters:(NSDictionary<NSNumber *, AccountDatacenterInfo *> *)datacenters notificationKey:(AccountNotificationKey *)notificationKey {
    self = [super init];
    if (self != nil) {
        _accountId = accountId;
        _primaryId = primaryId;
        _isTestingEnvironment = isTestingEnvironment;
        _peerName = peerName;
        _datacenters = datacenters;
        _notificationKey = notificationKey;
    }
    return self;
}

+ (instancetype _Nullable)parse:(NSDictionary *)dict {
    NSNumber *idNumber = dict[@"id"];
    if (![idNumber isKindOfClass:[NSNumber class]]) {
        return nil;
    }
    int64_t accountId = [idNumber longLongValue];
    
    NSNumber *primaryIdNumber = dict[@"primaryId"];
    if (![primaryIdNumber isKindOfClass:[NSNumber class]]) {
        return nil;
    }
    
    int32_t primaryId = [primaryIdNumber intValue];
    
    NSNumber *isTestingEnvironmentNumber = dict[@"isTestingEnvironment"];
    if (![isTestingEnvironmentNumber isKindOfClass:[NSNumber class]]) {
        return nil;
    }
    
    bool isTestingEnvironment = [isTestingEnvironmentNumber intValue] != 0;
    
    NSString *peerNameString = dict[@"peerName"];
    if (![peerNameString isKindOfClass:[NSString class]]) {
        return nil;
    }
    
    NSString *peerName = peerNameString;
    
    NSArray *datacentersArray = dict[@"datacenters"];
    if (![datacentersArray isKindOfClass:[NSArray class]]) {
        return nil;
    }
    
    NSMutableDictionary<NSNumber *, AccountDatacenterInfo *> *datacenters = [[NSMutableDictionary alloc] init];
    
    for (NSInteger i = 0; i < datacentersArray.count; i += 2) {
        NSNumber *datacenterKey = datacentersArray[i];
        NSDictionary *datacenterData = datacentersArray[i + 1];
        
        if (![datacenterKey isKindOfClass:[NSNumber class]]) {
            return nil;
        }
        if (![datacenterData isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        AccountDatacenterInfo *parsedDatacenter = [AccountDatacenterInfo parse:datacenterData];
        if (parsedDatacenter != nil) {
            datacenters[datacenterKey] = parsedDatacenter;
        }
    }
    
    NSDictionary *notificationKeyDict = dict[@"notificationKey"];
    if (![notificationKeyDict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AccountNotificationKey *notificationKey = [AccountNotificationKey parse:notificationKeyDict];
    if (notificationKey == nil) {
        return nil;
    }
    
    return [[StoredAccountInfo alloc] initWithAccountId:accountId primaryId:primaryId isTestingEnvironment:isTestingEnvironment peerName:peerName datacenters:datacenters notificationKey:notificationKey];
}

@end

@implementation StoredAccountInfos

- (instancetype)initWithProxy:(AccountProxyConnection * _Nullable)proxy accounts:(NSArray<StoredAccountInfo *> *)accounts {
    self = [super init];
    if (self != nil) {
        _proxy = proxy;
        _accounts = accounts;
    }
    return self;
}

+ (StoredAccountInfos * _Nullable)loadFromPath:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil) {
        return nil;
    }
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AccountProxyConnection * _Nullable proxy = nil;
    NSDictionary *proxyDict = dict[@"proxy"];
    if ([proxyDict isKindOfClass:[NSDictionary class]]) {
        proxy = [AccountProxyConnection parse:proxyDict];
    }
    
    NSMutableArray<StoredAccountInfo *> *accounts = [[NSMutableArray alloc] init];
    
    NSArray *accountsObject = dict[@"accounts"];
    if ([accountsObject isKindOfClass:[NSArray class]]) {
        for (NSDictionary *object in accountsObject) {
            if ([object isKindOfClass:[NSDictionary class]]) {
                StoredAccountInfo *account = [StoredAccountInfo parse:object];
                if (account != nil) {
                    [accounts addObject:account];
                }
            }
        }
    }
    
    return [[StoredAccountInfos alloc] initWithProxy:proxy accounts:accounts];;
}

@end

static NSData *sha256Digest(NSData *data) {
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    
    return [[NSData alloc] initWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
}

static NSData *concatData(NSData *data1, NSData *data2) {
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:data1.length + data2.length];
    [data appendData:data1];
    [data appendData:data2];
    return data;
}

static NSData *concatData3(NSData *data1, NSData *data2, NSData *data3) {
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:data1.length + data2.length + data3.length];
    [data appendData:data1];
    [data appendData:data2];
    [data appendData:data3];
    return data;
}

NSDictionary * _Nullable decryptedNotificationPayload(NSArray<StoredAccountInfo *> *accounts, NSData *data, int *selectedAccountIndex) {
    if (data.length < 8 + 16) {
        return nil;
    }
    
    int accountIndex = -1;
    for (StoredAccountInfo *account in accounts) {
        accountIndex += 1;
        
        AccountNotificationKey *notificationKey = account.notificationKey;
        if (![[data subdataWithRange:NSMakeRange(0, 8)] isEqualToData:notificationKey.keyId]) {
            continue;
        }
        
        int x = 8;
        NSData *msgKey = [data subdataWithRange:NSMakeRange(8, 16)];
        NSData *rawData = [data subdataWithRange:NSMakeRange(8 + 16, data.length - (8 + 16))];
        
        NSData *sha256_a = sha256Digest(concatData(msgKey, [notificationKey.data subdataWithRange:NSMakeRange(x, 36)]));
        NSData *sha256_b = sha256Digest(concatData([notificationKey.data subdataWithRange:NSMakeRange(40 + x, 36)], msgKey));
        NSData *aesKey = concatData3([sha256_a subdataWithRange:NSMakeRange(0, 8)], [sha256_b subdataWithRange:NSMakeRange(8, 16)], [sha256_a subdataWithRange:NSMakeRange(24, 8)]);
        NSData *aesIv = concatData3([sha256_b subdataWithRange:NSMakeRange(0, 8)], [sha256_a subdataWithRange:NSMakeRange(8, 16)], [sha256_b subdataWithRange:NSMakeRange(24, 8)]);
        
        NSData *decryptedData = MTAesDecrypt(rawData, aesKey, aesIv);
        if (decryptedData.length <= 4) {
            return nil;
        }
        
        int32_t dataLength = 0;
        [decryptedData getBytes:&dataLength range:NSMakeRange(0, 4)];
        
        if (dataLength < 0 || dataLength > decryptedData.length - 4) {
            return nil;
        }
        
        NSData *checkMsgKeyLarge = sha256Digest(concatData([notificationKey.data subdataWithRange:NSMakeRange(88 + x, 32)], decryptedData));
        NSData *checkMsgKey = [checkMsgKeyLarge subdataWithRange:NSMakeRange(8, 16)];
        
        if (![checkMsgKey isEqualToData:msgKey]) {
            return nil;
        }
        
        NSData *contentData = [decryptedData subdataWithRange:NSMakeRange(4, dataLength)];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:contentData options:0 error:nil];
        if (![dict isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        if (selectedAccountIndex != nil) {
            *selectedAccountIndex = accountIndex;
        }
        return dict;
    }
    return nil;
}
