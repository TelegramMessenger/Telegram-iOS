#import "FetchImage.h"

#import <MtProtoKit/MtProtoKit.h>
#import <OpenSSLEncryptionProvider/OpenSSLEncryptionProvider.h>

#import "Serialization.h"

@interface InMemoryKeychain : NSObject <MTKeychain> {
    NSMutableDictionary *_dict;
}

@end

@implementation InMemoryKeychain

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _dict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)setObject:(id)object forKey:(NSString *)aKey group:(NSString *)group {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
    _dict[[NSString stringWithFormat:@"%@:%@", group, aKey]] = data;
}

- (id)objectForKey:(NSString *)aKey group:(NSString *)group {
    NSData *data = _dict[[NSString stringWithFormat:@"%@:%@", group, aKey]];
    if (data != nil) {
        return [NSKeyedUnarchiver unarchiveObjectWithData:data];
    } else {
        return nil;
    }
}

- (void)removeObjectForKey:(NSString *)aKey group:(NSString *)group {
    [_dict removeObjectForKey:[NSString stringWithFormat:@"%@:%@", group, aKey]];
}

- (void)dropGroup:(NSString *)group {
}

@end

static void MTLoggingFunction(NSString *string, va_list args) {
    NSLogv(string, args);
}

@interface ParsedFile : NSObject

@property (nonatomic, strong, readonly) NSData * _Nullable data;

@end

@implementation ParsedFile

- (instancetype)initWithData:(NSData * _Nullable)data {
    self = [super init];
    if (self != nil) {
        _data = data;
    }
    return self;
}

@end

dispatch_block_t fetchImage(BuildConfig *buildConfig, AccountProxyConnection * _Nullable proxyConnection, StoredAccountInfo *account, Api1_InputFileLocation *inputFileLocation, int32_t datacenterId, void (^completion)(NSData * _Nullable)) {
    MTLogSetEnabled(true);
    MTLogSetLoggingFunction(&MTLoggingFunction);
    
    Serialization *serialization = [[Serialization alloc] init];
    
    MTApiEnvironment *apiEnvironment = [[MTApiEnvironment alloc] init];
    
    apiEnvironment.apiId = buildConfig.apiId;
    apiEnvironment.langPack = @"ios";
    apiEnvironment.layer = @([serialization currentLayer]);
    apiEnvironment.disableUpdates = true;
    apiEnvironment = [apiEnvironment withUpdatedLangPackCode:@""];
    
    if (proxyConnection != nil) {
        apiEnvironment = [apiEnvironment withUpdatedSocksProxySettings:[[MTSocksProxySettings alloc] initWithIp:proxyConnection.host port:(uint16_t)proxyConnection.port username:proxyConnection.username password:proxyConnection.password secret:proxyConnection.secret]];
    }
    
    MTContext *context = [[MTContext alloc] initWithSerialization:serialization encryptionProvider:[[OpenSSLEncryptionProvider alloc] init] apiEnvironment:apiEnvironment isTestingEnvironment:account.isTestingEnvironment useTempAuthKeys:true];
    context.tempKeyExpiration = 10 * 60 * 60;
    
    NSDictionary *seedAddressList = @{};
    
    if (account.isTestingEnvironment) {
        seedAddressList = @{
            @(1): @[@"149.154.175.10"],
            @(2): @[@"149.154.167.40"]
        };
    } else {
        seedAddressList = @{
            @(1): @[@"149.154.175.50", @"2001:b28:f23d:f001::a"],
            @(2): @[@"149.154.167.50", @"2001:67c:4e8:f002::a"],
            @(3): @[@"149.154.175.100", @"2001:b28:f23d:f003::a"],
            @(4): @[@"149.154.167.91", @"2001:67c:4e8:f004::a"],
            @(5): @[@"149.154.171.5", @"2001:b28:f23f:f005::a"]
        };
    }
    
    for (NSNumber *datacenterId in seedAddressList) {
        NSMutableArray *addressList = [[NSMutableArray alloc] init];
        for (NSString *host in seedAddressList[datacenterId]) {
            [addressList addObject:[[MTDatacenterAddress alloc] initWithIp:host port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil]];
        }
        [context setSeedAddressSetForDatacenterWithId:[datacenterId intValue] seedAddressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:addressList]];
    }
    
    InMemoryKeychain *keychain = [[InMemoryKeychain alloc] init];
    context.keychain = keychain;
    
    [context performBatchUpdates:^{
        for (NSNumber *datacenterId in account.datacenters) {
            AccountDatacenterInfo *info = account.datacenters[datacenterId];
            if (info.addressList.count != 0) {
                NSMutableArray *list = [[NSMutableArray alloc] init];
                for (AccountDatacenterAddress *address in info.addressList) {
                    [list addObject:[[MTDatacenterAddress alloc] initWithIp:address.host port:address.port preferForMedia:address.isMedia restrictToTcp:false cdn:false preferForProxy:address.isProxy secret:address.secret]];
                }
                [context updateAddressSetForDatacenterWithId:[datacenterId intValue] addressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:list] forceUpdateSchemes:true];
            }
        }
    }];
    
    for (NSNumber *datacenterId in account.datacenters) {
        AccountDatacenterInfo *info = account.datacenters[datacenterId];
        MTDatacenterAuthInfo *authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:info.masterKey.data authKeyId:info.masterKey.keyId saltSet:@[] authKeyAttributes:@{}];
        
        [context updateAuthInfoForDatacenterWithId:[datacenterId intValue] authInfo:authInfo selector:MTDatacenterAuthInfoSelectorPersistent];
        
        if (info.ephemeralMainKey != nil) {
            MTDatacenterAuthInfo *ephemeralMainAuthInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:info.ephemeralMainKey.data authKeyId:info.ephemeralMainKey.keyId saltSet:@[] authKeyAttributes:@{}];
            [context updateAuthInfoForDatacenterWithId:[datacenterId intValue] authInfo:ephemeralMainAuthInfo selector:MTDatacenterAuthInfoSelectorEphemeralMain];
        }
        
        if (info.ephemeralMediaKey != nil) {
            MTDatacenterAuthInfo *ephemeralMediaAuthInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:info.ephemeralMediaKey.data authKeyId:info.ephemeralMediaKey.keyId saltSet:@[] authKeyAttributes:@{}];
            [context updateAuthInfoForDatacenterWithId:[datacenterId intValue] authInfo:ephemeralMediaAuthInfo selector:MTDatacenterAuthInfoSelectorEphemeralMedia];
        }
    }
    
    MTProto *mtProto = [[MTProto alloc] initWithContext:context datacenterId:datacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    mtProto.useTempAuthKeys = context.useTempAuthKeys;
    mtProto.checkForProxyConnectionIssues = false;
    
    MTRequestMessageService *requestService = [[MTRequestMessageService alloc] initWithContext:context];
    [mtProto addMessageService:requestService];
    
    MTRequest *request = [[MTRequest alloc] init];
    
    MTOutputStream *outputStream = [[MTOutputStream alloc] init];
    [outputStream writeInt32:-475607115]; //upload.getFile
    [outputStream writeData:[Api1__Environment serializeObject:inputFileLocation]];
    
    [outputStream writeInt32:0];
    [outputStream writeInt32:32 * 1024];
    
    [request setPayload:[outputStream currentBytes] metadata:@"getFile" shortMetadata:@"getFile" responseParser:^id(NSData *response) {
        MTInputStream *inputStream = [[MTInputStream alloc] initWithData:response];
        int32_t signature = [inputStream readInt32];
        if (signature != 157948117) {
            return [[ParsedFile alloc] initWithData:nil];
        }
        [inputStream readInt32]; //type
        [inputStream readInt32]; //mtime
        
        return [[ParsedFile alloc] initWithData:[inputStream readBytes]];
    }];
    
    request.dependsOnPasswordEntry = false;
    request.shouldContinueExecutionWithErrorContext = ^bool (__unused MTRequestErrorContext *errorContext) {
        return true;
    };
    
    request.completed = ^(id boxedResponse, __unused NSTimeInterval completionTimestamp, MTRpcError *error) {
        if (error != nil) {
            if (completion) {
                completion(nil);
            }
        } else {
            if ([boxedResponse isKindOfClass:[ParsedFile class]]) {
                if (completion) {
                    completion(((ParsedFile *)boxedResponse).data);
                }
            } else {
                if (completion) {
                    completion(nil);
                }
            }
        }
    };
    
    [requestService addRequest:request];
    [mtProto resume];
    
    id internalId = request.internalId;
    return ^{
        [requestService removeRequestByInternalId:internalId];
        [context performBatchUpdates:^{
        }];
        [mtProto stop];
    };
}
