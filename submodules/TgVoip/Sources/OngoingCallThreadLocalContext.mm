#import "OngoingCallThreadLocalContext.h"

#import "TgVoip.h"

#import <MtProtoKit/MtProtoKit.h>
#include <memory>

#import <libkern/OSAtomic.h>

static void TGCallAesIgeEncrypt(uint8_t *inBytes, uint8_t *outBytes, size_t length, uint8_t *key, uint8_t *iv) {
    MTAesEncryptRaw(inBytes, outBytes, length, key, iv);
}

static void TGCallAesIgeDecrypt(uint8_t *inBytes, uint8_t *outBytes, size_t length, uint8_t *key, uint8_t *iv) {
    MTAesDecryptRaw(inBytes, outBytes, length, key, iv);
}

static void TGCallSha1(uint8_t *msg, size_t length, uint8_t *output) {
    MTRawSha1(msg, length, output);
}

static void TGCallSha256(uint8_t *msg, size_t length, uint8_t *output) {
    MTRawSha256(msg, length, output);
}

static void TGCallAesCtrEncrypt(uint8_t *inOut, size_t length, uint8_t *key, uint8_t *iv, uint8_t *ecount, uint32_t *num) {
    uint8_t *outData = (uint8_t *)malloc(length);
    MTAesCtr *aesCtr = [[MTAesCtr alloc] initWithKey:key keyLength:32 iv:iv ecount:ecount num:*num];
    [aesCtr encryptIn:inOut out:outData len:length];
    memcpy(inOut, outData, length);
    free(outData);
    
    [aesCtr getIv:iv];
    
    memcpy(ecount, [aesCtr ecount], 16);
    *num = [aesCtr num];
}

static void TGCallRandomBytes(uint8_t *buffer, size_t length) {
    arc4random_buf(buffer, length);
}

@implementation OngoingCallConnectionDescription

- (instancetype _Nonnull)initWithConnectionId:(int64_t)connectionId ip:(NSString * _Nonnull)ip ipv6:(NSString * _Nonnull)ipv6 port:(int32_t)port peerTag:(NSData * _Nonnull)peerTag {
    self = [super init];
    if (self != nil) {
        _connectionId = connectionId;
        _ip = ip;
        _ipv6 = ipv6;
        _port = port;
        _peerTag = peerTag;
    }
    return self;
}

@end

static MTAtomic *callContexts() {
    static MTAtomic *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MTAtomic alloc] initWithValue:[[NSMutableDictionary alloc] init]];
    });
    return instance;
}

@interface OngoingCallThreadLocalContextReference : NSObject

@property (nonatomic, weak) OngoingCallThreadLocalContext *context;
@property (nonatomic, strong, readonly) id<OngoingCallThreadLocalContextQueue> queue;

@end

@implementation OngoingCallThreadLocalContextReference

- (instancetype)initWithContext:(OngoingCallThreadLocalContext *)context queue:(id<OngoingCallThreadLocalContextQueue>)queue {
    self = [super init];
    if (self != nil) {
        self.context = context;
        _queue = queue;
    }
    return self;
}

@end

static int32_t nextId = 1;

static int32_t addContext(OngoingCallThreadLocalContext *context, id<OngoingCallThreadLocalContextQueue> queue) {
    int32_t contextId = OSAtomicIncrement32(&nextId);
    [callContexts() with:^id(NSMutableDictionary *dict) {
        dict[@(contextId)] = [[OngoingCallThreadLocalContextReference alloc] initWithContext:context queue:queue];
        return nil;
    }];
    return contextId;
}

static void removeContext(int32_t contextId) {
    [callContexts() with:^id(NSMutableDictionary *dict) {
        [dict removeObjectForKey:@(contextId)];
        return nil;
    }];
}

static void withContext(int32_t contextId, void (^f)(OngoingCallThreadLocalContext *)) {
    __block OngoingCallThreadLocalContextReference *reference = nil;
    [callContexts() with:^id(NSMutableDictionary *dict) {
        reference = dict[@(contextId)];
        return nil;
    }];
    if (reference != nil) {
        [reference.queue dispatch:^{
            __strong OngoingCallThreadLocalContext *context = reference.context;
            if (context != nil) {
                f(context);
            }
        }];
    }
}

@interface OngoingCallThreadLocalContext () {
    id<OngoingCallThreadLocalContextQueue> _queue;
    int32_t _contextId;

    OngoingCallNetworkType _networkType;
    NSTimeInterval _callReceiveTimeout;
    NSTimeInterval _callRingTimeout;
    NSTimeInterval _callConnectTimeout;
    NSTimeInterval _callPacketTimeout;
    
    std::unique_ptr<TgVoip> _tgVoip;
    
    OngoingCallState _state;
    int32_t _signalBars;
    NSData *_lastDerivedState;
}

- (void)controllerStateChanged:(TgVoipState)state;
- (void)signalBarsChanged:(int32_t)signalBars;

@end

@implementation VoipProxyServer

- (instancetype _Nonnull)initWithHost:(NSString * _Nonnull)host port:(int32_t)port username:(NSString * _Nullable)username password:(NSString * _Nullable)password {
    self = [super init];
    if (self != nil) {
        _host = host;
        _port = port;
        _username = username;
        _password = password;
    }
    return self;
}

@end

static TgVoipNetworkType callControllerNetworkTypeForType(OngoingCallNetworkType type) {
    switch (type) {
    case OngoingCallNetworkTypeWifi:
        return TgVoipNetworkType::WiFi;
    case OngoingCallNetworkTypeCellularGprs:
        return TgVoipNetworkType::Gprs;
    case OngoingCallNetworkTypeCellular3g:
        return TgVoipNetworkType::ThirdGeneration;
    case OngoingCallNetworkTypeCellularLte:
        return TgVoipNetworkType::Lte;
    default:
        return TgVoipNetworkType::ThirdGeneration;
    }
}

static TgVoipDataSaving callControllerDataSavingForType(OngoingCallDataSaving type) {
    switch (type) {
    case OngoingCallDataSavingNever:
        return TgVoipDataSaving::Never;
    case OngoingCallDataSavingCellular:
        return TgVoipDataSaving::Mobile;
    case OngoingCallDataSavingAlways:
        return TgVoipDataSaving::Always;
    default:
        return TgVoipDataSaving::Never;
    }
}

@implementation OngoingCallThreadLocalContext

static void (*InternalVoipLoggingFunction)(NSString *) = NULL;

+ (void)setupLoggingFunction:(void (*)(NSString *))loggingFunction {
    InternalVoipLoggingFunction = loggingFunction;
    TgVoip::setLoggingFunction([](std::string const &string) {
        if (InternalVoipLoggingFunction) {
            InternalVoipLoggingFunction([[NSString alloc] initWithUTF8String:string.c_str()]);
        }
    });
}

+ (void)applyServerConfig:(NSString *)string {
    if (string.length != 0) {
        TgVoip::setGlobalServerConfig(std::string(string.UTF8String));
    }
}

+ (int32_t)maxLayer {
    return 92;
}

+ (NSString *)version {
    return [NSString stringWithUTF8String:TgVoip::getVersion().c_str()];
}

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueue> _Nonnull)queue proxy:(VoipProxyServer * _Nullable)proxy networkType:(OngoingCallNetworkType)networkType dataSaving:(OngoingCallDataSaving)dataSaving derivedState:(NSData * _Nonnull)derivedState key:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing primaryConnection:(OngoingCallConnectionDescription * _Nonnull)primaryConnection alternativeConnections:(NSArray<OngoingCallConnectionDescription *> * _Nonnull)alternativeConnections maxLayer:(int32_t)maxLayer allowP2P:(BOOL)allowP2P logPath:(NSString * _Nonnull)logPath {
    self = [super init];
    if (self != nil) {
        _queue = queue;
        assert([queue isCurrent]);
        _contextId = addContext(self, queue);
        
        _callReceiveTimeout = 20.0;
        _callRingTimeout = 90.0;
        _callConnectTimeout = 30.0;
        _callPacketTimeout = 10.0;
        _networkType = networkType;
        
        std::vector<uint8_t> derivedStateValue;
        derivedStateValue.resize(derivedState.length);
        [derivedState getBytes:derivedStateValue.data() length:derivedState.length];
        
        std::unique_ptr<TgVoipProxy> proxyValue = nullptr;
        if (proxy != nil) {
            TgVoipProxy *proxyObject = new TgVoipProxy();
            proxyObject->host = proxy.host.UTF8String;
            proxyObject->port = (uint16_t)proxy.port;
            proxyObject->login = proxy.username.UTF8String ?: "";
            proxyObject->password = proxy.password.UTF8String ?: "";
            proxyValue = std::unique_ptr<TgVoipProxy>(proxyObject);
        }
        
        TgVoipCrypto crypto;
        crypto.sha1 = &TGCallSha1;
        crypto.sha256 = &TGCallSha256;
        crypto.rand_bytes = &TGCallRandomBytes;
        crypto.aes_ige_encrypt = &TGCallAesIgeEncrypt;
        crypto.aes_ige_decrypt = &TGCallAesIgeDecrypt;
        crypto.aes_ctr_encrypt = &TGCallAesCtrEncrypt;
        
        std::vector<TgVoipEndpoint> endpoints;
        NSArray<OngoingCallConnectionDescription *> *connections = [@[primaryConnection] arrayByAddingObjectsFromArray:alternativeConnections];
        for (OngoingCallConnectionDescription *connection in connections) {
            unsigned char peerTag[16];
            [connection.peerTag getBytes:peerTag length:16];
            
            TgVoipEndpoint endpoint;
            endpoint.endpointId = connection.connectionId;
            endpoint.host = {
                .ipv4 = std::string(connection.ip.UTF8String),
                .ipv6 = std::string(connection.ipv6.UTF8String)
            };
            endpoint.port = (uint16_t)connection.port;
            endpoint.type = TgVoipEndpointType::UdpRelay;
            memcpy(endpoint.peerTag, peerTag, 16);
            endpoints.push_back(endpoint);
        }
        
        TgVoipConfig config;
        config.initializationTimeout = _callConnectTimeout;
        config.receiveTimeout = _callPacketTimeout;
        config.dataSaving = callControllerDataSavingForType(dataSaving);
        config.enableP2P = static_cast<bool>(allowP2P);
        config.enableAEC = false;
        config.enableNS = true;
        config.enableAGC = true;
        config.enableVolumeControl = false;
        config.enableCallUpgrade = false;
        config.logPath = logPath.length == 0 ? "" : std::string(logPath.UTF8String);
        config.maxApiLayer = [OngoingCallThreadLocalContext maxLayer];
        
        std::vector<uint8_t> encryptionKeyValue;
        encryptionKeyValue.resize(key.length);
        memcpy(encryptionKeyValue.data(), key.bytes, key.length);
        
        TgVoipEncryptionKey encryptionKey;
        encryptionKey.value = encryptionKeyValue;
        encryptionKey.isOutgoing = isOutgoing;
        
        _tgVoip = TgVoip::makeInstance(
            config,
            { derivedStateValue },
            endpoints,
            proxyValue.get(),
            callControllerNetworkTypeForType(networkType),
            encryptionKey,
            crypto
        );
        
        _state = OngoingCallStateInitializing;
        _signalBars = -1;
        
        __weak OngoingCallThreadLocalContext *weakSelf = self;
        _tgVoip->setOnStateUpdated([weakSelf](TgVoipState state) {
            __strong OngoingCallThreadLocalContext *strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf controllerStateChanged:state];
            }
        });
        _tgVoip->setOnSignalBarsUpdated([weakSelf](int signalBars) {
            __strong OngoingCallThreadLocalContext *strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf signalBarsChanged:signalBars];
            }
        });
    }
    return self;
}

- (void)dealloc {
    assert([_queue isCurrent]);
    removeContext(_contextId);
    if (_tgVoip != NULL) {
        [self stop:nil];
    }
}

- (void)stop:(void (^)(NSString *, int64_t, int64_t, int64_t, int64_t))completion {
    if (_tgVoip) {
        TgVoipFinalState finalState = _tgVoip->stop();
        
        NSString *debugLog = [NSString stringWithUTF8String:finalState.debugLog.c_str()];
        _lastDerivedState = [[NSData alloc] initWithBytes:finalState.persistentState.value.data() length:finalState.persistentState.value.size()];
        
        _tgVoip.reset();
        
        if (completion) {
            completion(debugLog, finalState.trafficStats.bytesSentWifi, finalState.trafficStats.bytesReceivedWifi, finalState.trafficStats.bytesSentMobile, finalState.trafficStats.bytesReceivedMobile);
        }
    }
}

- (NSString *)debugInfo {
    if (_tgVoip != nil) {
        auto rawDebugString = _tgVoip->getDebugInfo();
        return [NSString stringWithUTF8String:rawDebugString.c_str()];
    } else {
        return nil;
    }
}

- (NSString *)version {
    if (_tgVoip != nil) {
        return [NSString stringWithUTF8String:_tgVoip->getVersion().c_str()];
    } else {
        return nil;
    }
}

- (NSData * _Nonnull)getDerivedState {
    if (_tgVoip) {
        auto persistentState = _tgVoip->getPersistentState();
        return [[NSData alloc] initWithBytes:persistentState.value.data() length:persistentState.value.size()];
    } else if (_lastDerivedState != nil) {
        return _lastDerivedState;
    } else {
        return [NSData data];
    }
}

- (void)controllerStateChanged:(TgVoipState)state {
    OngoingCallState callState = OngoingCallStateInitializing;
    switch (state) {
        case TgVoipState::Established:
            callState = OngoingCallStateConnected;
            break;
        case TgVoipState::Failed:
            callState = OngoingCallStateFailed;
            break;
        case TgVoipState::Reconnecting:
            callState = OngoingCallStateReconnecting;
            break;
        default:
            break;
    }
    
    if (callState != _state) {
        _state = callState;
        
        if (_stateChanged) {
            _stateChanged(callState);
        }
    }
}

- (void)signalBarsChanged:(int32_t)signalBars {
    if (signalBars != _signalBars) {
        _signalBars = signalBars;
        
        if (_signalBarsChanged) {
            _signalBarsChanged(signalBars);
        }
    }
}

- (void)setIsMuted:(bool)isMuted {
    if (_tgVoip) {
        _tgVoip->setMuteMicrophone(isMuted);
    }
}

- (void)setNetworkType:(OngoingCallNetworkType)networkType {
    if (_networkType != networkType) {
        _networkType = networkType;
        if (_tgVoip) {
            _tgVoip->setNetworkType(callControllerNetworkTypeForType(networkType));
        }
    }
}

@end
