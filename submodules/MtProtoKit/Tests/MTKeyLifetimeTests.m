#import <XCTest/XCTest.h>
#import <objc/message.h>

#import <MtProtoKit/MTBindKeyMessageService.h>
#import <MtProtoKit/MTKeychain.h>
#import <MtProtoKit/MTDatacenterAuthMessageService.h>
#import <MtProtoKit/MTIncomingMessage.h>
#import <MtProtoKit/MTMessageTransaction.h>
#import <MtProtoKit/MTOutgoingMessage.h>
#import <MtProtoKit/MTSessionInfo.h>
#import <MtProtoKit/MTTcpTransport.h>

#import "MTTestSupport.h"
#import "MTResPqMessage.h"

static const NSInteger kDatacenterId = 2;

@protocol MTKeyLifetimeTestsPrivate

- (instancetype)initWithAuthInfo:(MTDatacenterAuthInfo *)authInfo selector:(MTDatacenterAuthInfoSelector)selector;
- (MTDatacenterAuthKey *)getAuthKeyForCurrentScheme:(MTTransportScheme *)scheme createIfNeeded:(bool)createIfNeeded authInfoSelector:(MTDatacenterAuthInfoSelector *)authInfoSelector;
- (NSArray *)convertPublicKeysFromDictionaries:(NSArray<NSDictionary *> *)list;

@end

static NSData *lifetimeRandomBytes(NSUInteger length) {
    NSMutableData *data = [[NSMutableData alloc] initWithLength:length];
    arc4random_buf(data.mutableBytes, length);
    return data;
}

static int32_t int32At(NSData *data, NSUInteger offset) {
    int32_t value = 0;
    [data getBytes:&value range:NSMakeRange(offset, 4)];
    return value;
}

static MTDatacenterAuthInfo *authInfoWithKeyId(int64_t keyId, int32_t validUntilTimestamp) {
    return [[MTDatacenterAuthInfo alloc] initWithAuthKey:lifetimeRandomBytes(256) authKeyId:keyId validUntilTimestamp:validUntilTimestamp saltSet:@[] authKeyAttributes:nil];
}

static NSDictionary *refreshActions(MTContext *context) {
    __block NSDictionary *actions = nil;
    [[MTContext contextQueue] dispatchOnQueue:^{
        actions = [[context valueForKey:@"_tempKeyRefreshActions"] copy];
    } synchronous:true];
    return actions;
}

static void setValidAuthInfo(MTProto *proto, MTDatacenterAuthInfo *authInfo, MTDatacenterAuthInfoSelector selector) {
    MTTestOnManagerQueue(^{
        id validAuthInfo = ((id (*)(id, SEL, id, MTDatacenterAuthInfoSelector))objc_msgSend)([NSClassFromString(@"MTProtoValidAuthInfo") alloc], @selector(initWithAuthInfo:selector:), authInfo, selector);
        [proto setValue:validAuthInfo forKey:@"_validAuthInfo"];
    });
}

static int64_t validKeyId(MTProto *proto) {
    __block int64_t keyId = 0;
    MTTestOnManagerQueue(^{
        keyId = [[[proto valueForKey:@"_validAuthInfo"] valueForKey:@"authInfo"] authKeyId];
    });
    return keyId;
}

static int64_t keyIdForNextTransaction(MTProto *proto) {
    __block int64_t keyId = 0;
    MTTransportScheme *scheme = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:MTTestMakeAddress(false) media:false];
    MTTestOnManagerQueue(^{
        MTDatacenterAuthInfoSelector selector = MTDatacenterAuthInfoSelectorPersistent;
        MTDatacenterAuthKey *key = ((MTDatacenterAuthKey *(*)(id, SEL, id, bool, MTDatacenterAuthInfoSelector *))objc_msgSend)(proto, @selector(getAuthKeyForCurrentScheme:createIfNeeded:authInfoSelector:), scheme, true, &selector);
        keyId = key.authKeyId;
    });
    return keyId;
}

@interface MTKeyLifetimeTestEncryptionProvider : NSObject

@property (atomic) NSInteger bignumContextRequests;

@end

@implementation MTKeyLifetimeTestEncryptionProvider

- (id)createBignumContext {
    self.bignumContextRequests += 1;
    return nil;
}

- (id)parseRSAPublicKey:(NSString *)publicKey {
    return nil;
}

@end

@interface MTKeyLifetimeTestKeychain : NSObject <MTKeychain>

@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *values;

@end

@implementation MTKeyLifetimeTestKeychain

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _values = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)setObject:(id)object forKey:(NSString *)aKey group:(NSString *)group {
    @synchronized (self) {
        _values[[NSString stringWithFormat:@"%@/%@", group, aKey]] = object;
    }
}

- (id)objectForKey:(NSString *)aKey group:(NSString *)group {
    @synchronized (self) {
        return _values[[NSString stringWithFormat:@"%@/%@", group, aKey]];
    }
}

- (NSDictionary *)dictionaryForKey:(NSString *)aKey group:(NSString *)group {
    id value = [self objectForKey:aKey group:group];
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

- (NSNumber *)numberForKey:(NSString *)aKey group:(NSString *)group {
    id value = [self objectForKey:aKey group:group];
    return [value isKindOfClass:[NSNumber class]] ? value : nil;
}

- (void)removeObjectForKey:(NSString *)aKey group:(NSString *)group {
    @synchronized (self) {
        [_values removeObjectForKey:[NSString stringWithFormat:@"%@/%@", group, aKey]];
    }
}

@end

static NSNumber *authInfoKey(int32_t datacenterId, MTDatacenterAuthInfoSelector selector) {
    return @((((int64_t)selector) << 32) | (int64_t)datacenterId);
}

@interface MTKeyLifetimeTests : XCTestCase
@end

@implementation MTKeyLifetimeTests

- (void)testInnerDataDatacenterIdFollowsTheDocumentation {
    XCTAssertEqual(MTDatacenterAuthInnerDataDatacenterId(2, false, false, false), 2);
    XCTAssertEqual(MTDatacenterAuthInnerDataDatacenterId(2, true, false, false), 10002);
    XCTAssertEqual(MTDatacenterAuthInnerDataDatacenterId(2, false, true, false), -2);
    XCTAssertEqual(MTDatacenterAuthInnerDataDatacenterId(2, true, true, false), -10002);
    XCTAssertEqual(MTDatacenterAuthInnerDataDatacenterId(203, false, true, true), 203, @"a CDN is never negated");
}

- (void)testInnerDataUsesTheConstructorsWithADatacenter {
    NSData *pq = lifetimeRandomBytes(8);
    NSData *p = lifetimeRandomBytes(4);
    NSData *q = lifetimeRandomBytes(4);
    NSData *nonce = lifetimeRandomBytes(16);
    NSData *serverNonce = lifetimeRandomBytes(16);
    NSData *newNonce = lifetimeRandomBytes(32);

    NSData *permanent = MTDatacenterAuthInnerData(pq, p, q, nonce, serverNonce, newNonce, -4, false, 86400);
    XCTAssertEqual((uint32_t)int32At(permanent, 0), 0xa9f55f95);
    XCTAssertEqual(permanent.length, 4 + 12 + 8 + 8 + 16 + 16 + 32 + 4);
    XCTAssertEqual(int32At(permanent, permanent.length - 4), -4);
    XCTAssertEqualObjects([permanent subdataWithRange:NSMakeRange(permanent.length - 36, 32)], newNonce);

    NSData *temporary = MTDatacenterAuthInnerData(pq, p, q, nonce, serverNonce, newNonce, 10002, true, 86400);
    XCTAssertEqual((uint32_t)int32At(temporary, 0), 0x56fddf88);
    XCTAssertEqual(temporary.length, permanent.length + 4);
    XCTAssertEqual(int32At(temporary, temporary.length - 8), 10002);
    XCTAssertEqual(int32At(temporary, temporary.length - 4), 86400);
}

- (void)testBindExpiresAtIsTheKeysOwnExpiryInServerTime {
    MTContext *context = MTTestMakeContext(true);
    [context setGlobalTimeDifference:100.0];
    MTProto *proto = [[MTProto alloc] initWithContext:context datacenterId:kDatacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    MTDatacenterAuthKey *persistentKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:lifetimeRandomBytes(256) authKeyId:1 validUntilTimestamp:INT32_MAX notBound:false];
    MTDatacenterAuthKey *ephemeralKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:lifetimeRandomBytes(256) authKeyId:2 validUntilTimestamp:1800000000 notBound:true];
    MTBindKeyMessageService *service = [[MTBindKeyMessageService alloc] initWithPersistentKey:persistentKey ephemeralKey:ephemeralKey completion:^(__unused bool success, __unused MTRpcError *error) {
    }];
    MTSessionInfo *sessionInfo = [[MTSessionInfo alloc] initWithRandomSessionIdAndContext:context];
    __block MTMessageTransaction *transaction = nil;
    MTTestOnManagerQueue(^{
        transaction = [service mtProtoMessageTransaction:proto authInfoSelector:MTDatacenterAuthInfoSelectorEphemeralMain sessionInfo:sessionInfo scheme:nil];
    });
    MTOutgoingMessage *message = transaction.messagePayload.firstObject;
    XCTAssertNotNil(message);
    XCTAssertEqual((uint32_t)int32At(message.data, 0), 0xcdd42a05);
    XCTAssertEqual(int32At(message.data, 20), 1800000100, @"expires_at is the key's expiry moved into server time, not now + 24 h");
}

- (void)testOnlyTheAppReplacesTemporaryKeys {
    MTContext *context = MTTestMakeContext(true);
    context.tempKeyExpiration = 40;
    MTTestSetAddress(context, kDatacenterId, false);
    int32_t now = (int32_t)[NSDate date].timeIntervalSince1970;
    [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorPersistent];
    [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:authInfoWithKeyId(80, now + 5) selector:MTDatacenterAuthInfoSelectorEphemeralMain];
    XCTAssertFalse(MTTestWaitUntil(2.5, ^bool{
        return refreshActions(context).count != 0;
    }), @"refreshesTemporaryKeys is off by default, as in app extensions");
}

- (void)testOnlyKeysThisProcessUsesAreReplaced {
    int32_t now = (int32_t)[NSDate date].timeIntervalSince1970;
    MTKeyLifetimeTestKeychain *keychain = [[MTKeyLifetimeTestKeychain alloc] init];
    [keychain setObject:@{
        authInfoKey((int32_t)kDatacenterId, MTDatacenterAuthInfoSelectorPersistent): MTTestMakeAuthInfo(),
        authInfoKey((int32_t)kDatacenterId, MTDatacenterAuthInfoSelectorEphemeralMain): authInfoWithKeyId(90, now + 5)
    } forKey:@"datacenterAuthInfoById" group:@"persistent"];
    MTContext *context = MTTestMakeContext(true);
    context.tempKeyExpiration = 40;
    context.refreshesTemporaryKeys = true;
    MTTestSetAddress(context, kDatacenterId, false);
    context.keychain = keychain;
    
    XCTAssertFalse(MTTestWaitUntil(2.5, ^bool{
        return refreshActions(context).count != 0;
    }), @"a key loaded from the keychain but never used by this process is left alone");
    XCTAssertEqual([context authInfoForDatacenterWithId:kDatacenterId selector:MTDatacenterAuthInfoSelectorEphemeralMain].authKeyId, 90);
    XCTAssertTrue(MTTestWaitUntil(3.0, ^bool{
        return refreshActions(context).count != 0;
    }), @"once a session asks for it, it is replaced before it expires");
}

- (void)testAnExpiredKeyIsLeftToTheRejectionPath {
    MTContext *context = MTTestMakeContext(true);
    context.tempKeyExpiration = 40;
    context.refreshesTemporaryKeys = true;
    MTTestSetAddress(context, kDatacenterId, false);
    int32_t now = (int32_t)[NSDate date].timeIntervalSince1970;
    [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorPersistent];
    [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:authInfoWithKeyId(81, now - 5) selector:MTDatacenterAuthInfoSelectorEphemeralMain];
    XCTAssertFalse(MTTestWaitUntil(2.5, ^bool{
        return refreshActions(context).count != 0;
    }));
}

- (void)testATemporaryKeyIsReplacedBeforeItExpires {
    MTContext *context = MTTestMakeContext(true);
    context.tempKeyExpiration = 40;
    context.refreshesTemporaryKeys = true;
    MTTestSetAddress(context, kDatacenterId, false);
    MTTestSetAddress(context, 3, false);
    MTTestSetAddress(context, 4, false);
    int32_t now = (int32_t)[NSDate date].timeIntervalSince1970;

    [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorPersistent];
    [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:authInfoWithKeyId(20, now + 12) selector:MTDatacenterAuthInfoSelectorEphemeralMain];
    [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:authInfoWithKeyId(21, now + 3600) selector:MTDatacenterAuthInfoSelectorEphemeralMedia];
    [context updateAuthInfoForDatacenterWithId:3 authInfo:authInfoWithKeyId(30, now + 12) selector:MTDatacenterAuthInfoSelectorEphemeralMain];
    [context updateAuthInfoForDatacenterWithId:4 authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorPersistent];
    [context updateAuthInfoForDatacenterWithId:4 authInfo:authInfoWithKeyId(40, INT32_MAX) selector:MTDatacenterAuthInfoSelectorEphemeralMain];

    XCTAssertEqual(refreshActions(context).count, 0, @"nothing is due yet: 12 s left, the margin is 10 s");
    XCTAssertTrue(MTTestWaitUntil(8.0, ^bool{
        return refreshActions(context).count != 0;
    }));
    NSDictionary *actions = refreshActions(context);
    XCTAssertEqual(actions.count, 1, @"only the bound key that is about to expire: %@", actions);
    XCTAssertEqual([context authInfoForDatacenterWithId:kDatacenterId selector:MTDatacenterAuthInfoSelectorEphemeralMain].authKeyId, 20, @"the old key stays in use until its replacement is bound");
}

- (void)testAConnectionSwitchesToAReplacementKey {
    MTContext *context = MTTestMakeContext(true);
    MTTestSetAddress(context, kDatacenterId, false);
    [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorPersistent];
    MTDatacenterAuthInfo *oldKey = authInfoWithKeyId(50, INT32_MAX - 1);
    [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:oldKey selector:MTDatacenterAuthInfoSelectorEphemeralMain];
    MTProto *proto = [[MTProto alloc] initWithContext:context datacenterId:kDatacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    proto.useTempAuthKeys = true;
    setValidAuthInfo(proto, oldKey, MTDatacenterAuthInfoSelectorEphemeralMain);
    XCTAssertEqual(keyIdForNextTransaction(proto), 50);
    
    [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:authInfoWithKeyId(51, INT32_MAX - 1) selector:MTDatacenterAuthInfoSelectorEphemeralMain];
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return validKeyId(proto) != 50; }), @"the connection keeps the replaced key");
    XCTAssertEqual(keyIdForNextTransaction(proto), 51);
    
    [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:[authInfoWithKeyId(51, INT32_MAX - 1) mergeSaltSet:@[] forTimestamp:0] selector:MTDatacenterAuthInfoSelectorEphemeralMain];
    MTTestOnManagerQueue(^{});
    XCTAssertEqual(validKeyId(proto), 51, @"an update of the same key (salts) is not a replacement");
    [proto stop];
}

- (void)testARejectionOfAReplacedKeyKeepsTheReplacement {
    for (NSNumber *canResetAuthData in @[@false, @true]) {
        MTContext *context = MTTestMakeContext(true);
        MTTestSetAddress(context, kDatacenterId, false);
        [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorPersistent];
        MTDatacenterAuthInfo *oldKey = authInfoWithKeyId(60, INT32_MAX - 1);
        [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:oldKey selector:MTDatacenterAuthInfoSelectorEphemeralMain];
        MTProto *proto = [[MTProto alloc] initWithContext:context datacenterId:kDatacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
        proto.useTempAuthKeys = true;
        proto.canResetAuthData = canResetAuthData.boolValue;
        setValidAuthInfo(proto, oldKey, MTDatacenterAuthInfoSelectorEphemeralMain);
        
        [[MTContext contextQueue] dispatchOnQueue:^{
            NSMutableDictionary *authInfos = [context valueForKey:@"_datacenterAuthInfoById"];
            for (NSNumber *key in [authInfos allKeys]) {
                if (((MTDatacenterAuthInfo *)authInfos[key]).authKeyId == 60) {
                    authInfos[key] = authInfoWithKeyId(61, INT32_MAX - 1);
                }
            }
        } synchronous:true];
        MTTransportScheme *scheme = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:MTTestMakeAddress(false) media:false];
        MTTestOnManagerQueue(^{
            [proto handleMissingKey:scheme];
        });
        [[MTContext contextQueue] dispatchOnQueue:^{} synchronous:true];
        
        XCTAssertEqual([context authInfoForDatacenterWithId:kDatacenterId selector:MTDatacenterAuthInfoSelectorEphemeralMain].authKeyId, 61, @"a -404 for the old key must not delete its replacement (canResetAuthData %@)", canResetAuthData);
        XCTAssertEqual(keyIdForNextTransaction(proto), 61);
        [proto stop];
    }
}

- (void)testAnActionWhosePermanentKeyVanishedFails {
    MTContext *context = MTTestMakeContext(true);
    MTTestSetAddress(context, kDatacenterId, false);
    __block NSNumber *result = nil;
    MTDatacenterAuthAction *action = [[MTDatacenterAuthAction alloc] initWithAuthKeyInfoSelector:MTDatacenterAuthInfoSelectorEphemeralMain isCdn:false skipBind:false completion:^(__unused MTDatacenterAuthAction *action, bool success) {
        result = @(success);
    }];
    [action execute:context datacenterId:kDatacenterId];
    MTDatacenterAuthKey *authKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:lifetimeRandomBytes(256) authKeyId:70 validUntilTimestamp:INT32_MAX - 1 notBound:true];
    MTTestOnManagerQueue(^{
        [(id<MTDatacenterAuthMessageServiceDelegate>)action authMessageServiceCompletedWithAuthKey:authKey timestamp:0 serverSalt:0];
    });
    XCTAssertEqualObjects(result, @NO, @"the action must end so the context can ask again, not wait forever");
    [action cancel];
}

- (void)testACdnFingerprintMismatchFetchesTheCdnKeysOnceThenUsesTheOnlyKey {
    MTKeyLifetimeTestEncryptionProvider *provider = [[MTKeyLifetimeTestEncryptionProvider alloc] init];
    MTContext *context = MTTestMakeContextWithEncryptionProvider(false, (id<EncryptionProvider>)provider);
    [context updatePublicKeysForDatacenterWithId:203 publicKeys:@[@{@"key": @"-----BEGIN RSA PUBLIC KEY-----\nAAAA\n-----END RSA PUBLIC KEY-----"}]];
    MTProto *proto = [[MTProto alloc] initWithContext:context datacenterId:203 usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    proto.useUnauthorizedMode = true;
    proto.cdn = true;
    MTDatacenterAuthMessageService *service = [[MTDatacenterAuthMessageService alloc] initWithContext:context tempAuth:false];
    MTTestOnManagerQueue(^{
        [service mtProtoDidAddService:proto];
    });
    NSData *nonce = lifetimeRandomBytes(16);
    MTResPqMessage *resPq = [[MTResPqMessage alloc] initWithNonce:nonce serverNonce:lifetimeRandomBytes(16) pq:[NSData dataWithBytes:(uint8_t[]){0x17, 0xed, 0x48, 0x94, 0x1a, 0x08, 0xf9, 0x81} length:8] serverPublicKeyFingerprints:@[@(0x1234)]];
    MTIncomingMessage *message = [[MTIncomingMessage alloc] initWithMessageId:1 seqNo:0 authKeyId:0 sessionId:0 salt:0 timestamp:0.0 size:0 body:resPq];
    
    __block int32_t stage = -1;
    __block bool refetched = false;
    void (^deliver)(void) = ^{
        MTTestOnManagerQueue(^{
            [service setValue:@1 forKey:@"_stage"];
            [service setValue:nonce forKey:@"_nonce"];
            [service mtProto:proto receivedMessage:message authInfoSelector:MTDatacenterAuthInfoSelectorPersistent networkType:0];
            stage = [[service valueForKey:@"_stage"] intValue];
            refetched = [[service valueForKey:@"_cdnPublicKeysRefetched"] boolValue];
        });
    };
    
    deliver();
    XCTAssertEqual(stage, 0, @"the first mismatch waits for fresh CDN keys");
    XCTAssertTrue(refetched);
    
    MTTestOnManagerQueue(^{
        NSArray *keys = [(id<MTKeyLifetimeTestsPrivate>)service convertPublicKeysFromDictionaries:[context publicKeysForDatacenterWithId:203]];
        [service setValue:keys forKey:@"_publicKeys"];
    });
    NSInteger before = provider.bignumContextRequests;
    MTTestOnManagerQueue(^{
        [service setValue:@1 forKey:@"_stage"];
        [service setValue:nonce forKey:@"_nonce"];
        [service mtProto:proto receivedMessage:message authInfoSelector:MTDatacenterAuthInfoSelectorPersistent networkType:0];
    });
    XCTAssertEqual(provider.bignumContextRequests - before, 3, @"two fingerprint lookups, then RSA_PAD with the only CDN key from the main datacenter, as before (a rejected key stops after the first lookup)");
    [proto stop];
}

@end
