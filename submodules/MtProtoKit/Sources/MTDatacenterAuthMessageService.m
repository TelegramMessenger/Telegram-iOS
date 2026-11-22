#import <MtProtoKit/MTDatacenterAuthMessageService.h>

#import <MtProtoKit/MTLogging.h>
#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTProto.h>
#import <MtProtoKit/MTSerialization.h>
#import <MtProtoKit/MTSessionInfo.h>
#import <MtProtoKit/MTIncomingMessage.h>
#import <MtProtoKit/MTOutgoingMessage.h>
#import <MtProtoKit/MTMessageTransaction.h>
#import <MtProtoKit/MTPreparedMessage.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>
#import <MtProtoKit/MTDatacenterSaltInfo.h>
#import "MTBuffer.h"
#import "MTBufferReader.h"
#import <MtProtoKit/MTEncryption.h>
#import <MtProtoKit/MTTimer.h>
#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTTransportScheme.h>
#import <CommonCrypto/CommonCrypto.h>

#import "MTInternalInterfaces.h"

#import "MTInternalMessageParser.h"
#import "MTServerDhInnerDataMessage.h"
#import "MTResPqMessage.h"
#import "MTServerDhParamsMessage.h"
#import "MTSetClientDhParamsResponseMessage.h"

@interface MTDatacenterAuthPublicKey : NSObject

@property (nonatomic, strong, readonly) NSString *publicKey;

@end

@implementation MTDatacenterAuthPublicKey

- (instancetype)initWithPublicKey:(NSString *)publicKey {
    self = [super init];
    if (self != nil) {
        _publicKey = publicKey;
    }
    return self;
}

- (uint64_t)fingerprintWithEncryptionProvider:(id<EncryptionProvider>)encryptionProvider {
    return MTRsaFingerprint(encryptionProvider, _publicKey);
}

@end

static NSArray<MTDatacenterAuthPublicKey *> *defaultPublicKeys(bool isProduction) {
    static NSArray<MTDatacenterAuthPublicKey *> *testingPublicKeys = nil;
    static NSArray<MTDatacenterAuthPublicKey *> *productionPublicKeys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        testingPublicKeys = @[
            [[MTDatacenterAuthPublicKey alloc] initWithPublicKey:@"-----BEGIN RSA PUBLIC KEY-----\n"
             "MIIBCgKCAQEAyMEdY1aR+sCR3ZSJrtztKTKqigvO/vBfqACJLZtS7QMgCGXJ6XIR\n"
             "yy7mx66W0/sOFa7/1mAZtEoIokDP3ShoqF4fVNb6XeqgQfaUHd8wJpDWHcR2OFwv\n"
             "plUUI1PLTktZ9uW2WE23b+ixNwJjJGwBDJPQEQFBE+vfmH0JP503wr5INS1poWg/\n"
             "j25sIWeYPHYeOrFp/eXaqhISP6G+q2IeTaWTXpwZj4LzXq5YOpk4bYEQ6mvRq7D1\n"
             "aHWfYmlEGepfaYR8Q0YqvvhYtMte3ITnuSJs171+GDqpdKcSwHnd6FudwGO4pcCO\n"
             "j4WcDuXc2CTHgH8gFTNhp/Y8/SpDOhvn9QIDAQAB\n"
             "-----END RSA PUBLIC KEY-----"]
        ];

        productionPublicKeys = @[
            [[MTDatacenterAuthPublicKey alloc] initWithPublicKey:@"-----BEGIN RSA PUBLIC KEY-----\n"
             "MIIBCgKCAQEA6LszBcC1LGzyr992NzE0ieY+BSaOW622Aa9Bd4ZHLl+TuFQ4lo4g\n"
             "5nKaMBwK/BIb9xUfg0Q29/2mgIR6Zr9krM7HjuIcCzFvDtr+L0GQjae9H0pRB2OO\n"
             "62cECs5HKhT5DZ98K33vmWiLowc621dQuwKWSQKjWf50XYFw42h21P2KXUGyp2y/\n"
             "+aEyZ+uVgLLQbRA1dEjSDZ2iGRy12Mk5gpYc397aYp438fsJoHIgJ2lgMv5h7WY9\n"
             "t6N/byY9Nw9p21Og3AoXSL2q/2IJ1WRUhebgAdGVMlV1fkuOQoEzR7EdpqtQD9Cs\n"
             "5+bfo3Nhmcyvk5ftB0WkJ9z6bNZ7yxrP8wIDAQAB\n"
             "-----END RSA PUBLIC KEY-----"]
        ];
    });
    if (isProduction) {
        return productionPublicKeys;
    } else {
        return testingPublicKeys;
    }
}

NSArray<NSString *> *MTDatacenterAuthDefaultPublicKeys(bool isProduction) {
    NSMutableArray<NSString *> *result = [[NSMutableArray alloc] init];
    for (MTDatacenterAuthPublicKey *key in defaultPublicKeys(isProduction)) {
        [result addObject:key.publicKey];
    }
    return result;
}

static MTDatacenterAuthPublicKey *selectPublicKey(id<EncryptionProvider> encryptionProvider, NSArray<NSNumber *> *fingerprints, NSArray<MTDatacenterAuthPublicKey *> *publicKeys) {
    NSMutableArray<NSNumber *> *keyFingerprints = [[NSMutableArray alloc] init];
    for (MTDatacenterAuthPublicKey *key in publicKeys) {
        [keyFingerprints addObject:@([key fingerprintWithEncryptionProvider:encryptionProvider])];
    }
    
    for (NSNumber *nFingerprint in fingerprints) {
        for (NSUInteger i = 0; i < publicKeys.count; i++) {
            if ([nFingerprint unsignedLongLongValue] == [keyFingerprints[i] unsignedLongLongValue]) {
                return publicKeys[i];
            }
        }
    }

    return nil;
}

static NSTimeInterval MTDatacenterAuthRetryDelay(NSUInteger failureCount) {
    if (failureCount <= 1) {
        return 0.0;
    }
    return pow(2.0, (double)MIN(failureCount - 2, (NSUInteger)4));
}

int32_t MTDatacenterAuthInnerDataDatacenterId(NSInteger datacenterId, bool isTestingEnvironment, bool media, bool cdn) {
    int32_t datacenter = (int32_t)datacenterId;
    if (isTestingEnvironment) {
        datacenter += 10000;
    }
    if (media && !cdn) {
        datacenter = -datacenter;
    }
    return datacenter;
}

NSData *MTDatacenterAuthInnerData(NSData *pq, NSData *p, NSData *q, NSData *nonce, NSData *serverNonce, NSData *newNonce, int32_t datacenterId, bool temporary, int32_t expiresIn) {
    MTBuffer *buffer = [[MTBuffer alloc] init];
    [buffer appendInt32:temporary ? (int32_t)0x56fddf88 : (int32_t)0xa9f55f95];
    [buffer appendTLBytes:pq];
    [buffer appendTLBytes:p];
    [buffer appendTLBytes:q];
    [buffer appendBytes:nonce.bytes length:nonce.length];
    [buffer appendBytes:serverNonce.bytes length:serverNonce.length];
    [buffer appendBytes:newNonce.bytes length:newNonce.length];
    [buffer appendInt32:datacenterId];
    if (temporary) {
        [buffer appendInt32:expiresIn];
    }
    return buffer.data;
}

static NSUInteger serverDhInnerDataLength(NSData *data) {
    MTBufferReader *reader = [[MTBufferReader alloc] initWithData:data];
    int32_t signature = 0;
    if (![reader readInt32:&signature] || signature != (int32_t)0xb5890dba) {
        return 0;
    }
    if (![reader readBytes:NULL length:16 + 16 + 4]) {
        return 0;
    }
    if (![reader readTLBytes:NULL] || ![reader readTLBytes:NULL]) {
        return 0;
    }
    if (![reader readInt32:NULL]) {
        return 0;
    }
    return data.length - [reader readRest].length;
}

typedef enum {
    MTDatacenterAuthStageWaitingForPublicKeys = 0,
    MTDatacenterAuthStagePQ = 1,
    MTDatacenterAuthStageReqDH = 2,
    MTDatacenterAuthStageKeyVerification = 3,
    MTDatacenterAuthStageDone = 4
} MTDatacenterAuthStage;

@interface MTDatacenterAuthMessageService ()
{
    id<EncryptionProvider> _encryptionProvider;
    
    bool _tempAuth;
    
    MTDatacenterAuthStage _stage;
    int64_t _currentStageMessageId;
    int32_t _currentStageMessageSeqNo;
    id _currentStageTransactionId;
    
    NSData *_nonce;
    NSData *_serverNonce;
    NSData *_newNonce;
    
    NSData *_dhP;
    NSData *_dhQ;
    int64_t _dhPublicKeyFingerprint;
    NSData *_dhEncryptedData;
    
    MTDatacenterAuthKey *_authKey;
    int64_t _serverSalt;
    NSData *_encryptedClientData;
    
    NSArray<MTDatacenterAuthPublicKey *> *_publicKeys;
    
    NSUInteger _failureCount;
    MTTimer *_retryTimer;
    bool _transactionSchemeIsMedia;
    int32_t _tempKeyValidUntilTimestamp;
    bool _cdnPublicKeysRefetched;
}

@end

@implementation MTDatacenterAuthMessageService

- (instancetype)initWithContext:(MTContext *)context tempAuth:(bool)tempAuth
{
    self = [super init];
    if (self != nil)
    {
        _encryptionProvider = context.encryptionProvider;
        _tempAuth = tempAuth;
    }
    return self;
}

- (void)dealloc
{
    [_retryTimer invalidate];
}

- (NSArray<MTDatacenterAuthPublicKey *> *)convertPublicKeysFromDictionaries:(NSArray<NSDictionary *> *)list {
    NSMutableArray<MTDatacenterAuthPublicKey *> *cdnKeys = [[NSMutableArray alloc] init];
    for (NSDictionary *dict in list) {
        NSString *key = dict[@"key"];
        if ([key isKindOfClass:[NSString class]]) {
            [cdnKeys addObject:[[MTDatacenterAuthPublicKey alloc] initWithPublicKey:key]];
        }
    }
    return cdnKeys;
}

- (void)reset:(MTProto *)mtProto
{
    _currentStageMessageId = 0;
    _currentStageMessageSeqNo = 0;
    _currentStageTransactionId = nil;
    
    _nonce = nil;
    _serverNonce = nil;
    _newNonce = nil;
    
    _dhP = nil;
    _dhQ = nil;
    _dhPublicKeyFingerprint = 0;
    _dhEncryptedData = nil;
    
    _authKey = nil;
    _serverSalt = 0;
    _encryptedClientData = nil;
    
    if (mtProto.cdn) {
        _publicKeys = [self convertPublicKeysFromDictionaries:[mtProto.context publicKeysForDatacenterWithId:mtProto.datacenterId]];
        if (_publicKeys.count == 0) {
            _stage = MTDatacenterAuthStageWaitingForPublicKeys;
            [mtProto.context publicKeysForDatacenterWithIdRequired:mtProto.datacenterId];
        } else {
            _stage = MTDatacenterAuthStagePQ;
        }
    } else {
        _publicKeys = defaultPublicKeys(!mtProto.context.isTestingEnvironment);
        _stage = MTDatacenterAuthStagePQ;
    }
    
    [mtProto requestSecureTransportReset];
    if (_retryTimer == nil) {
        [mtProto requestTransportTransaction];
    }
}

- (void)fail:(MTProto *)mtProto
{
    _failureCount += 1;
    [_retryTimer invalidate];
    _retryTimer = nil;
    
    NSTimeInterval delay = MTDatacenterAuthRetryDelay(_failureCount);
    if (delay > 0.0) {
        if (MTLogEnabled()) {
            MTLog(@"[MTDatacenterAuthMessageService#%p failure %d, retrying in %.0f s]", self, (int)_failureCount, delay);
        }
        __weak MTDatacenterAuthMessageService *weakSelf = self;
        __weak MTProto *weakMtProto = mtProto;
        _retryTimer = [[MTTimer alloc] initWithTimeout:delay repeat:false completion:^{
            __strong MTDatacenterAuthMessageService *strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            strongSelf->_retryTimer = nil;
            __strong MTProto *strongMtProto = weakMtProto;
            [strongMtProto requestTransportTransaction];
        } queue:[MTProto managerQueue].nativeQueue];
        [_retryTimer start];
    }
    
    [self reset:mtProto];
}

- (void)mtProtoDidAddService:(MTProto *)mtProto
{
    [self reset:mtProto];
}
    
- (void)mtProtoPublicKeysUpdated:(MTProto *)mtProto datacenterId:(NSInteger)datacenterId publicKeys:(NSArray<NSDictionary *> *)publicKeys {
    if (!mtProto.cdn) {
        return;
    }

    if (_stage == MTDatacenterAuthStageWaitingForPublicKeys) {
        if (mtProto.datacenterId == datacenterId) {
            _publicKeys = [self convertPublicKeysFromDictionaries:publicKeys];
            if (_publicKeys != nil && _publicKeys.count != 0) {
                _stage = MTDatacenterAuthStagePQ;
                [mtProto requestTransportTransaction];
            }
        }
    }
}

- (MTMessageTransaction *)mtProtoMessageTransaction:(MTProto *)mtProto authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector sessionInfo:(MTSessionInfo *)sessionInfo scheme:(MTTransportScheme *)scheme
{
    if (MTLogEnabled()) {
        MTLog(@"[MTDatacenterAuthMessageService#%p mtProto#%p (media: %s) mtProtoMessageTransaction scheme:%@]", self, mtProto, mtProto.media ? "true" : "false", scheme);
    }

    if (_retryTimer != nil) {
        return nil;
    }
    _transactionSchemeIsMedia = scheme.media;
    
    if (_currentStageTransactionId == nil)
    {
        switch (_stage)
        {
            case MTDatacenterAuthStageWaitingForPublicKeys:
                break;
            case MTDatacenterAuthStagePQ:
            {
                if (_nonce == nil)
                {
                    uint8_t nonceBytes[16];
                    if (SecRandomCopyBytes(kSecRandomDefault, 16, nonceBytes) != errSecSuccess) {
                        [self fail:mtProto];
                        return nil;
                    }
                    _nonce = [[NSData alloc] initWithBytes:nonceBytes length:16];
                }
                
                MTBuffer *reqPqBuffer = [[MTBuffer alloc] init];
                [reqPqBuffer appendInt32:(int32_t)0xbe7e8ef1];
                [reqPqBuffer appendBytes:_nonce.bytes length:_nonce.length];
                
                NSString *messageDescription = [NSString stringWithFormat:@"reqPq nonce:%@", _nonce];
                MTOutgoingMessage *message = [[MTOutgoingMessage alloc] initWithData:reqPqBuffer.data metadata:messageDescription additionalDebugDescription:nil shortMetadata:messageDescription messageId:_currentStageMessageId messageSeqNo:_currentStageMessageSeqNo];
                return [[MTMessageTransaction alloc] initWithMessagePayload:@[message] prepared:nil failed:nil completion:^(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
                {
                    if (_stage == MTDatacenterAuthStagePQ && messageInternalIdToTransactionId[message.internalId] != nil && messageInternalIdToPreparedMessage[message.internalId] != nil)
                    {
                        MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[message.internalId];
                        _currentStageMessageId = preparedMessage.messageId;
                        _currentStageMessageSeqNo = preparedMessage.seqNo;
                        _currentStageTransactionId = messageInternalIdToTransactionId[message.internalId];
                    }
                }];
            }
            case MTDatacenterAuthStageReqDH:
            {
#if DEBUG
                if (arc4random_uniform(100) < 50) {
                    [mtProto simulateDisconnection];
                }
#endif
                
                MTBuffer *reqDhBuffer = [[MTBuffer alloc] init];
                [reqDhBuffer appendInt32:(int32_t)0xd712e4be];
                [reqDhBuffer appendBytes:_nonce.bytes length:_nonce.length];
                [reqDhBuffer appendBytes:_serverNonce.bytes length:_serverNonce.length];
                [reqDhBuffer appendTLBytes:_dhP];
                [reqDhBuffer appendTLBytes:_dhQ];
                [reqDhBuffer appendInt64:_dhPublicKeyFingerprint];
                [reqDhBuffer appendTLBytes:_dhEncryptedData];
                
                NSString *messageDescription = [NSString stringWithFormat:@"reqDh nonce:%@ serverNonce:%@ p:%@ q:%@ fingerprint:%llx dhEncryptedData:%d bytes", _nonce, _serverNonce, _dhP, _dhQ, _dhPublicKeyFingerprint, (int)_dhEncryptedData.length];
                MTOutgoingMessage *message = [[MTOutgoingMessage alloc] initWithData:reqDhBuffer.data metadata:messageDescription additionalDebugDescription:nil shortMetadata:messageDescription messageId:_currentStageMessageId messageSeqNo:_currentStageMessageSeqNo];
                return [[MTMessageTransaction alloc] initWithMessagePayload:@[message] prepared:nil failed:nil completion:^(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
                {
                    if (_stage == MTDatacenterAuthStageReqDH && messageInternalIdToTransactionId[message.internalId] != nil && messageInternalIdToPreparedMessage[message.internalId] != nil)
                    {
                        MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[message.internalId];
                        _currentStageMessageId = preparedMessage.messageId;
                        _currentStageMessageSeqNo = preparedMessage.seqNo;
                        _currentStageTransactionId = messageInternalIdToTransactionId[message.internalId];
                    }
                }];
            }
            case MTDatacenterAuthStageKeyVerification:
            {
                MTBuffer *setDhParamsBuffer = [[MTBuffer alloc] init];
                [setDhParamsBuffer appendInt32:(int32_t)0xf5045f1f];
                [setDhParamsBuffer appendBytes:_nonce.bytes length:_nonce.length];
                [setDhParamsBuffer appendBytes:_serverNonce.bytes length:_serverNonce.length];
                [setDhParamsBuffer appendTLBytes:_encryptedClientData];
                
                MTOutgoingMessage *message = [[MTOutgoingMessage alloc] initWithData:setDhParamsBuffer.data metadata:@"setDhParams" additionalDebugDescription:nil shortMetadata:@"setDhParams" messageId:_currentStageMessageId messageSeqNo:_currentStageMessageSeqNo];
                return [[MTMessageTransaction alloc] initWithMessagePayload:@[message] prepared:nil failed:nil completion:^(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
                {
                    if (_stage == MTDatacenterAuthStageKeyVerification && messageInternalIdToTransactionId[message.internalId] != nil && messageInternalIdToPreparedMessage[message.internalId] != nil)
                    {
                        MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[message.internalId];
                        _currentStageMessageId = preparedMessage.messageId;
                        _currentStageMessageSeqNo = preparedMessage.seqNo;
                        _currentStageTransactionId = messageInternalIdToTransactionId[message.internalId];
                    }
                }];
            }
            default:
                break;
        }
    }
    
    return nil;
}

static NSData *reversedBytes(NSData *data) {
    NSMutableData *result = [[NSMutableData alloc] initWithLength:data.length];
    for (NSUInteger i = 0; i < result.length; i++) {
        ((uint8_t *)result.mutableBytes)[i] = ((uint8_t *)data.bytes)[result.length - i - 1];
    }
    return result;
}

static NSData *encryptRSAModernPadding(id<EncryptionProvider> encryptionProvider, NSData *pqInnerData, NSString *publicKey) {
    NSMutableData *dataWithPadding = [[NSMutableData alloc] init];
    [dataWithPadding appendData:pqInnerData];
    if (dataWithPadding.length > 144) {
        return nil;
    }
    if (dataWithPadding.length != 192) {
        int originalLength = (int)dataWithPadding.length;
        int numPaddingBytes = 192 - originalLength;
        [dataWithPadding setLength:192];
        int randomResult = SecRandomCopyBytes(kSecRandomDefault, numPaddingBytes, ((uint8_t *)dataWithPadding.mutableBytes) + originalLength);
        if (randomResult != errSecSuccess) {
            return nil;
        }
    }

    NSData *dataWithPaddingReversed = reversedBytes(dataWithPadding);

    id<MTBignumContext> bignumContext = [encryptionProvider createBignumContext];
    if (bignumContext == nil) {
        return nil;
    }
    id<MTRsaPublicKey> rsaPublicKey = [encryptionProvider parseRSAPublicKey:publicKey];
    if (rsaPublicKey == nil) {
        return nil;
    }
    id<MTBignum> rsaModule = [bignumContext rsaGetN:rsaPublicKey];
    if (rsaModule == nil) {
        return nil;
    }
    if ([bignumContext getBin:rsaModule].length != 256) {
        return nil;
    }

    for (int attempt = 0; attempt < 4096; attempt++) {
        int randomResult = 0;
        NSMutableData *tempKey = [[NSMutableData alloc] initWithLength:32];
        randomResult = SecRandomCopyBytes(kSecRandomDefault, tempKey.length, tempKey.mutableBytes);
        if (randomResult != errSecSuccess) {
            return nil;
        }

        NSMutableData *tempKeyAndDataWithPadding = [[NSMutableData alloc] init];
        [tempKeyAndDataWithPadding appendData:tempKey];
        [tempKeyAndDataWithPadding appendData:dataWithPadding];

        NSMutableData *dataWithHash = [[NSMutableData alloc] init];
        [dataWithHash appendData:dataWithPaddingReversed];
        [dataWithHash appendData:MTSha256(tempKeyAndDataWithPadding)];
        if (dataWithHash.length != 224) {
            return nil;
        }

        NSMutableData *zeroIv = [[NSMutableData alloc] initWithLength:32];
        memset(zeroIv.mutableBytes, 0, zeroIv.length);

        NSData *aesEncrypted = MTAesEncrypt(dataWithHash, tempKey, zeroIv);
        if (aesEncrypted == nil) {
            return nil;
        }
        NSData *shaAesEncrypted = MTSha256(aesEncrypted);

        NSMutableData *tempKeyXor = [[NSMutableData alloc] initWithLength:tempKey.length];
        if (tempKeyXor.length != shaAesEncrypted.length) {
            return nil;
        }
        for (NSUInteger i = 0; i < tempKey.length; i++) {
            ((uint8_t *)tempKeyXor.mutableBytes)[i] = ((uint8_t *)tempKey.bytes)[i] ^ ((uint8_t *)shaAesEncrypted.bytes)[i];
        }

        NSMutableData *keyAesEncrypted = [[NSMutableData alloc] init];
        [keyAesEncrypted appendData:tempKeyXor];
        [keyAesEncrypted appendData:aesEncrypted];
        if (keyAesEncrypted.length != 256) {
            return nil;
        }

        id<MTBignum> bignumKeyAesEncrypted = [bignumContext create];
        if (bignumKeyAesEncrypted == nil) {
            return nil;
        }
        [bignumContext assignBinTo:bignumKeyAesEncrypted value:keyAesEncrypted];
        int compareResult = [bignumContext compare:rsaModule with:bignumKeyAesEncrypted];
        if (compareResult <= 0) {
            continue;
        }

        NSData *encryptedData = [encryptionProvider rsaEncryptWithPublicKey:publicKey data:keyAesEncrypted];
        if (encryptedData == nil || encryptedData.length > 256) {
            return nil;
        }
        NSMutableData *paddedEncryptedData = [[NSMutableData alloc] init];
        [paddedEncryptedData appendData:encryptedData];
        while (paddedEncryptedData.length < 256) {
            uint8_t zero = 0;
            [paddedEncryptedData replaceBytesInRange:NSMakeRange(0, 0) withBytes:&zero length:1];
        }

        if (paddedEncryptedData.length != 256) {
            return nil;
        }

        return paddedEncryptedData;
    }
    
    return nil;
}

- (void)mtProto:(MTProto *)mtProto receivedMessage:(MTIncomingMessage *)message authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector networkType:(int32_t)networkType
{
    if (_stage == MTDatacenterAuthStagePQ && [message.body isKindOfClass:[MTResPqMessage class]])
    {
        MTResPqMessage *resPqMessage = message.body;
        
        if ([_nonce isEqualToData:resPqMessage.nonce])
        {
            MTDatacenterAuthPublicKey *publicKey = selectPublicKey(_encryptionProvider, resPqMessage.serverPublicKeyFingerprints, _publicKeys);
            
            if (publicKey == nil && mtProto.cdn && !_cdnPublicKeysRefetched)
            {
                if (MTLogEnabled()) {
                    MTLog(@"[MTDatacenterAuthMessageService#%p no CDN key matches the server, fetching the CDN keys again]", self);
                }
                _cdnPublicKeysRefetched = true;
                [self reset:mtProto];
                _stage = MTDatacenterAuthStageWaitingForPublicKeys;
                _publicKeys = nil;
                [mtProto.context publicKeysForDatacenterWithIdRequired:mtProto.datacenterId];
                
                return;
            }
            
            if (publicKey == nil && mtProto.cdn && resPqMessage.serverPublicKeyFingerprints.count == 1 && _publicKeys.count == 1) {
                if (MTLogEnabled()) {
                    MTLog(@"[MTDatacenterAuthMessageService#%p no CDN key matches the server after a refetch, using the only CDN key the main datacenter gave]", self);
                }
                publicKey = _publicKeys[0];
            }
            
            if (publicKey == nil)
            {
                if (MTLogEnabled()) {
                    MTLog(@"[MTDatacenterAuthMessageService#%p couldn't find valid server public key]", self);
                }
                [self fail:mtProto];
            }
            else
            {
                NSData *pqBytes = resPqMessage.pq;
                if (pqBytes.length == 0 || pqBytes.length > 8)
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid pq length %d]", self, (int)pqBytes.length);
                    }
                    [self fail:mtProto];
                    
                    return;
                }
                
                uint64_t pq = 0;
                for (int i = 0; i < (int)pqBytes.length; i++)
                {
                    pq <<= 8;
                    pq |= ((uint8_t *)[pqBytes bytes])[i];
                }
                
                uint64_t factP = 0;
                uint64_t factQ = 0;
                if (pq < 4 || pq >= ((uint64_t)1 << 63) || !MTFactorize(pq, &factP, &factQ))
                {
                    [self fail:mtProto];
                    
                    return;
                }
                
                _serverNonce = resPqMessage.serverNonce;
                
                NSMutableData *pBytes = [[NSMutableData alloc] init];
                uint64_t p = factP;
                do
                {
                    [pBytes replaceBytesInRange:NSMakeRange(0, 0) withBytes:&p length:1];
                    p >>= 8;
                } while (p > 0);
                _dhP = pBytes;
                
                NSMutableData *qBytes = [[NSMutableData alloc] init];
                uint64_t q = factQ;
                do
                {
                    [qBytes replaceBytesInRange:NSMakeRange(0, 0) withBytes:&q length:1];
                    q >>= 8;
                } while (q > 0);
                _dhQ = qBytes;
                
                _dhPublicKeyFingerprint = [publicKey fingerprintWithEncryptionProvider:_encryptionProvider];
                
                uint8_t nonceBytes[32];
                if (SecRandomCopyBytes(kSecRandomDefault, 32, nonceBytes) != errSecSuccess) {
                    [self fail:mtProto];
                    
                    return;
                }
                _newNonce = [[NSData alloc] initWithBytes:nonceBytes length:32];
                
                /*
                 p_q_inner_data_dc#a9f55f95 pq:string p:string q:string nonce:int128 server_nonce:int128 new_nonce:int256 dc:int = P_Q_inner_data;
                 p_q_inner_data_temp_dc#56fddf88 pq:string p:string q:string nonce:int128 server_nonce:int128 new_nonce:int256 dc:int expires_in:int = P_Q_inner_data;
                 */
                
                int32_t innerDataDatacenterId = MTDatacenterAuthInnerDataDatacenterId(mtProto.datacenterId, mtProto.context.isTestingEnvironment, _transactionSchemeIsMedia, mtProto.cdn);
                
                if (_tempAuth) {
                    _tempKeyValidUntilTimestamp = ((int32_t)([NSDate date].timeIntervalSince1970)) + mtProto.context.tempKeyExpiration;
                }
                NSData *innerDataBytes = MTDatacenterAuthInnerData(pqBytes, _dhP, _dhQ, _nonce, _serverNonce, _newNonce, innerDataDatacenterId, _tempAuth, mtProto.context.tempKeyExpiration);
                _dhEncryptedData = encryptRSAModernPadding(_encryptionProvider, innerDataBytes, publicKey.publicKey);
                if (MTLogEnabled()) {
                    MTLog(@"[MTDatacenterAuthMessageService#%p inner data for dc %d (%s), encryptedData length %d]", self, (int)innerDataDatacenterId, _tempAuth ? "temporary" : "permanent", (int)_dhEncryptedData.length);
                }

                if (_dhEncryptedData == nil) {
                    [self fail:mtProto];
                } else {
                    _stage = MTDatacenterAuthStageReqDH;
                    _currentStageMessageId = 0;
                    _currentStageMessageSeqNo = 0;
                    _currentStageTransactionId = nil;
                    [mtProto requestTransportTransaction];
                }
            }
        }
    }
    else if (_stage == MTDatacenterAuthStageReqDH && [message.body isKindOfClass:[MTServerDhParamsMessage class]])
    {
        MTServerDhParamsMessage *serverDhParamsMessage = message.body;
        
        if ([_nonce isEqualToData:serverDhParamsMessage.nonce] && [_serverNonce isEqualToData:serverDhParamsMessage.serverNonce])
        {
            if ([serverDhParamsMessage isKindOfClass:[MTServerDhParamsOkMessage class]])
            {
                NSMutableData *tmpAesKey = [[NSMutableData alloc] init];
                
                NSMutableData *newNonceAndServerNonce = [[NSMutableData alloc] init];
                [newNonceAndServerNonce appendData:_newNonce];
                [newNonceAndServerNonce appendData:_serverNonce];
                
                NSMutableData *serverNonceAndNewNonce = [[NSMutableData alloc] init];
                [serverNonceAndNewNonce appendData:_serverNonce];
                [serverNonceAndNewNonce appendData:_newNonce];
                [tmpAesKey appendData:MTSha1(newNonceAndServerNonce)];
                
                NSData *serverNonceAndNewNonceHash = MTSha1(serverNonceAndNewNonce);
                NSData *serverNonceAndNewNonceHash0_12 = [[NSData alloc] initWithBytes:((uint8_t *)serverNonceAndNewNonceHash.bytes) length:12];
                
                [tmpAesKey appendData:serverNonceAndNewNonceHash0_12];
                
                NSMutableData *tmpAesIv = [[NSMutableData alloc] init];
                
                NSData *serverNonceAndNewNonceHash12_8 = [[NSData alloc] initWithBytes:(((uint8_t *)serverNonceAndNewNonceHash.bytes) + 12) length:8];
                [tmpAesIv appendData:serverNonceAndNewNonceHash12_8];
                
                NSMutableData *newNonceAndNewNonce = [[NSMutableData alloc] init];
                [newNonceAndNewNonce appendData:_newNonce];
                [newNonceAndNewNonce appendData:_newNonce];
                [tmpAesIv appendData:MTSha1(newNonceAndNewNonce)];
                
                NSData *newNonce0_4 = [[NSData alloc] initWithBytes:((uint8_t *)_newNonce.bytes) length:4];
                [tmpAesIv appendData:newNonce0_4];
                
                NSData *answerWithHash = MTAesDecrypt(((MTServerDhParamsOkMessage *)serverDhParamsMessage).encryptedResponse, tmpAesKey, tmpAesIv);
                if (answerWithHash == nil || answerWithHash.length < 20) {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p couldn't decrypt DH params]", self);
                    }
                    [self fail:mtProto];
                    
                    return;
                }
                NSData *answerHash = [answerWithHash subdataWithRange:NSMakeRange(0, 20)];
                NSData *answerAndPadding = [answerWithHash subdataWithRange:NSMakeRange(20, answerWithHash.length - 20)];
                NSUInteger answerLength = serverDhInnerDataLength(answerAndPadding);
                
                if (answerLength == 0 || answerAndPadding.length - answerLength >= 16)
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p couldn't decode DH params]", self);
                    }
                    [self fail:mtProto];
                    
                    return;
                }
                
                NSData *answerData = [answerAndPadding subdataWithRange:NSMakeRange(0, answerLength)];
                if (![MTSha1(answerData) isEqualToData:answerHash])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p couldn't verify DH params]", self);
                    }
                    [self fail:mtProto];
                    
                    return;
                }
                
                MTServerDhInnerDataMessage *dhInnerData = [MTInternalMessageParser parseMessage:answerData];
                
                if (![dhInnerData isKindOfClass:[MTServerDhInnerDataMessage class]])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p couldn't parse decoded DH params]", self);
                    }
                    [self fail:mtProto];
                    
                    return;
                }
                
                if (![_nonce isEqualToData:dhInnerData.nonce])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH nonce]", self);
                    }
                    [self fail:mtProto];
                    
                    return;
                }
                
                if (![_serverNonce isEqualToData:dhInnerData.serverNonce])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH server nonce]", self);
                    }
                    [self fail:mtProto];
                    
                    return;
                }
                
                int32_t innerDataG = dhInnerData.g;
                if (innerDataG < 0 || !MTCheckIsSafeG((unsigned int)innerDataG))
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH g]", self);
                    }
                    [self fail:mtProto];
                    
                    return;
                }
                
                NSData *innerDataGA = dhInnerData.gA;
                NSData *innerDataDhPrime = dhInnerData.dhPrime;
                if (!MTCheckIsSafeGAOrB(_encryptionProvider, innerDataGA, innerDataDhPrime))
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH g_a]", self);
                    }
                    [self fail:mtProto];
                    
                    return;
                }
                
                if (!MTCheckMod(_encryptionProvider, innerDataDhPrime, (unsigned int)innerDataG, mtProto.context.keychain))
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH g (2)]", self);
                    }
                    [self fail:mtProto];
                    
                    return;
                }
                
                if (!MTCheckIsSafePrime(_encryptionProvider, innerDataDhPrime, mtProto.context.keychain))
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH prime]", self);
                    }
                    [self fail:mtProto];
                    
                    return;
                }
                
                int32_t tmpG = innerDataG;
                tmpG = (int32_t)OSSwapInt32(tmpG);
                NSData *g = [[NSData alloc] initWithBytes:&tmpG length:4];
                
                NSData *b = nil;
                NSData *g_b = nil;
                for (int attempt = 0; attempt < 8 && g_b == nil; attempt++)
                {
                    uint8_t bBytes[256];
                    if (SecRandomCopyBytes(kSecRandomDefault, 256, bBytes) != errSecSuccess) {
                        break;
                    }
                    NSData *candidateB = [[NSData alloc] initWithBytes:bBytes length:256];
                    NSData *candidateGB = MTExp(_encryptionProvider, g, candidateB, innerDataDhPrime);
                    if (candidateGB != nil && MTCheckIsSafeGAOrB(_encryptionProvider, candidateGB, innerDataDhPrime)) {
                        b = candidateB;
                        g_b = candidateGB;
                    }
                }
                
                if (g_b == nil)
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p couldn't generate DH g_b]", self);
                    }
                    [self fail:mtProto];
                    
                    return;
                }
                
                NSData *authKey = MTExp(_encryptionProvider, innerDataGA, b, innerDataDhPrime);
                if (authKey != nil && authKey.length < 256) {
                    NSMutableData *paddedAuthKey = [[NSMutableData alloc] initWithLength:256 - authKey.length];
                    [paddedAuthKey appendData:authKey];
                    authKey = paddedAuthKey;
                }
                if (authKey.length != 256)
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p couldn't compute DH auth key]", self);
                    }
                    [self fail:mtProto];
                    
                    return;
                }
                
                NSData *authKeyHash = MTSha1(authKey);
                
                int64_t authKeyId = 0;
                memcpy(&authKeyId, (((uint8_t *)authKeyHash.bytes) + authKeyHash.length - 8), 8);
                NSMutableData *serverSaltData = [[NSMutableData alloc] init];
                for (int i = 0; i < 8; i++)
                {
                    int8_t a = ((int8_t *)_newNonce.bytes)[i];
                    int8_t b = ((int8_t *)_serverNonce.bytes)[i];
                    int8_t x = a ^ b;
                    [serverSaltData appendBytes:&x length:1];
                }
                memcpy(&_serverSalt, serverSaltData.bytes, 8);
                
                int32_t validUntilTimestamp = _tempAuth ? _tempKeyValidUntilTimestamp : INT32_MAX;
                _authKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:authKey authKeyId:authKeyId validUntilTimestamp:validUntilTimestamp notBound:_tempAuth];
                
                MTBuffer *clientDhInnerDataBuffer = [[MTBuffer alloc] init];
                [clientDhInnerDataBuffer appendInt32:(int32_t)0x6643b654];
                [clientDhInnerDataBuffer appendBytes:_nonce.bytes length:_nonce.length];
                [clientDhInnerDataBuffer appendBytes:_serverNonce.bytes length:_serverNonce.length];
                [clientDhInnerDataBuffer appendInt64:0];
                [clientDhInnerDataBuffer appendTLBytes:g_b];
                
                NSData *clientInnerDataBytes = clientDhInnerDataBuffer.data;
                
                NSMutableData *clientDataWithHash = [[NSMutableData alloc] init];
                [clientDataWithHash appendData:MTSha1(clientInnerDataBytes)];
                [clientDataWithHash appendData:clientInnerDataBytes];
                while (clientDataWithHash.length % 16 != 0)
                {
                    uint8_t randomByte = 0;
                    arc4random_buf(&randomByte, 1);
                    [clientDataWithHash appendBytes:&randomByte length:1];
                }
                
                _encryptedClientData = MTAesEncrypt(clientDataWithHash, tmpAesKey, tmpAesIv);
                if (_encryptedClientData == nil)
                {
                    [self fail:mtProto];
                    
                    return;
                }
                
                _stage = MTDatacenterAuthStageKeyVerification;
                _currentStageMessageId = 0;
                _currentStageMessageSeqNo = 0;
                _currentStageTransactionId = nil;
                [mtProto requestTransportTransaction];
            }
            else
            {
                if (MTLogEnabled()) {
                    MTLog(@"[MTDatacenterAuthMessageService#%p couldn't set DH params]", self);
                }
                [self fail:mtProto];
            }
        }
    }
    else if (_stage == MTDatacenterAuthStageKeyVerification && [message.body isKindOfClass:[MTSetClientDhParamsResponseMessage class]])
    {
        MTSetClientDhParamsResponseMessage *setClientDhParamsResponseMessage = message.body;
        
        if ([_nonce isEqualToData:setClientDhParamsResponseMessage.nonce] && [_serverNonce isEqualToData:setClientDhParamsResponseMessage.serverNonce])
        {
            NSData *authKeyAuxHashFull = MTSha1(_authKey.authKey);
            NSData *authKeyAuxHash = [[NSData alloc] initWithBytes:((uint8_t *)authKeyAuxHashFull.bytes) length:8];
            
            NSMutableData *newNonce1 = [[NSMutableData alloc] init];
            [newNonce1 appendData:_newNonce];
            uint8_t tmp1 = 1;
            [newNonce1 appendBytes:&tmp1 length:1];
            [newNonce1 appendData:authKeyAuxHash];
            NSData *newNonceHash1Full = MTSha1(newNonce1);
            NSData *newNonceHash1 = [[NSData alloc] initWithBytes:(((uint8_t *)newNonceHash1Full.bytes) + newNonceHash1Full.length - 16) length:16];
            
            NSMutableData *newNonce2 = [[NSMutableData alloc] init];
            [newNonce2 appendData:_newNonce];
            uint8_t tmp2 = 2;
            [newNonce2 appendBytes:&tmp2 length:1];
            [newNonce2 appendData:authKeyAuxHash];
            NSData *newNonceHash2Full = MTSha1(newNonce2);
            NSData *newNonceHash2 = [[NSData alloc] initWithBytes:(((uint8_t *)newNonceHash2Full.bytes) + newNonceHash2Full.length - 16) length:16];
            
            NSMutableData *newNonce3 = [[NSMutableData alloc] init];
            [newNonce3 appendData:_newNonce];
            uint8_t tmp3 = 3;
            [newNonce3 appendBytes:&tmp3 length:1];
            [newNonce3 appendData:authKeyAuxHash];
            NSData *newNonceHash3Full = MTSha1(newNonce3);
            NSData *newNonceHash3 = [[NSData alloc] initWithBytes:(((uint8_t *)newNonceHash3Full.bytes) + newNonceHash3Full.length - 16) length:16];
            
            if ([setClientDhParamsResponseMessage isKindOfClass:[MTSetClientDhParamsResponseOkMessage class]])
            {
                if (![newNonceHash1 isEqualToData:((MTSetClientDhParamsResponseOkMessage *)setClientDhParamsResponseMessage).nextNonceHash1])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH answer nonce hash 1]", self);
                    }
                    [self fail:mtProto];
                }
                else
                {
                    _stage = MTDatacenterAuthStageDone;
                    _currentStageMessageId = 0;
                    _currentStageMessageSeqNo = 0;
                    _currentStageTransactionId = nil;
                    _failureCount = 0;
                    
                    id<MTDatacenterAuthMessageServiceDelegate> delegate = _delegate;
                    if ([delegate respondsToSelector:@selector(authMessageServiceCompletedWithAuthKey:timestamp:serverSalt:)])
                        [delegate authMessageServiceCompletedWithAuthKey:_authKey timestamp:message.messageId serverSalt:_serverSalt];
                }
            }
            else if ([setClientDhParamsResponseMessage isKindOfClass:[MTSetClientDhParamsResponseRetryMessage class]])
            {
                if (![newNonceHash2 isEqualToData:((MTSetClientDhParamsResponseRetryMessage *)setClientDhParamsResponseMessage).nextNonceHash2])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH answer nonce hash 2]", self);
                    }
                    [self fail:mtProto];
                }
                else
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p retry DH]", self);
                    }
                    [self fail:mtProto];
                }
            }
            else if ([setClientDhParamsResponseMessage isKindOfClass:[MTSetClientDhParamsResponseFailMessage class]])
            {
                if (![newNonceHash3 isEqualToData:((MTSetClientDhParamsResponseFailMessage *)setClientDhParamsResponseMessage).nextNonceHash3])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH answer nonce hash 3]", self);
                    }
                    [self fail:mtProto];
                }
                else
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p server rejected DH params]", self);
                    }
                    [self fail:mtProto];
                }
            }
            else
            {
                if (MTLogEnabled()) {
                    MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH params response]", self);
                }
                [self fail:mtProto];
            }
        }
    }
}

- (void)mtProto:(MTProto *)mtProto protocolErrorReceived:(int32_t)__unused errorCode
{
    [self fail:mtProto];
}

- (void)mtProto:(MTProto *)mtProto transactionsMayHaveFailed:(NSArray *)transactionIds
{
    if (_currentStageTransactionId != nil && [transactionIds containsObject:_currentStageTransactionId])
    {
        _currentStageTransactionId = nil;
        [mtProto requestTransportTransaction];
    }
}

- (void)mtProtoAllTransactionsMayHaveFailed:(MTProto *)mtProto
{
    if (_currentStageTransactionId != nil)
    {
        _currentStageTransactionId = nil;
        [mtProto requestTransportTransaction];
    }
}

@end
