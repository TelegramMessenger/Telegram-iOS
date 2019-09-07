#import "OngoingCallThreadLocalContext.h"

#import "VoIPController.h"
#import "VoIPServerConfig.h"
#import "os/darwin/SetupLogging.h"

#ifdef BUCK
#import <MtProtoKit/MtProtoKit.h>
#else
#import <MtProtoKitDynamic/MtProtoKitDynamic.h>
#endif

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
    int32_t _dataSavingMode;
    
    tgvoip::VoIPController *_controller;
    
    OngoingCallState _state;
    int32_t _signalBars;
    NSData *_lastDerivedState;
}

- (void)controllerStateChanged:(int)state;
- (void)signalBarsChanged:(int32_t)signalBars;

@end

static void controllerStateCallback(tgvoip::VoIPController *controller, int state) {
    int32_t contextId = (int32_t)((intptr_t)controller->implData);
    withContext(contextId, ^(OngoingCallThreadLocalContext *context) {
        [context controllerStateChanged:state];
    });
}

static void signalBarsCallback(tgvoip::VoIPController *controller, int signalBars) {
    int32_t contextId = (int32_t)((intptr_t)controller->implData);
    withContext(contextId, ^(OngoingCallThreadLocalContext *context) {
        [context signalBarsChanged:(int32_t)signalBars];
    });
}

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

static int callControllerNetworkTypeForType(OngoingCallNetworkType type) {
    switch (type) {
        case OngoingCallNetworkTypeWifi:
            return tgvoip::NET_TYPE_WIFI;
        case OngoingCallNetworkTypeCellularGprs:
            return tgvoip::NET_TYPE_GPRS;
        case OngoingCallNetworkTypeCellular3g:
            return tgvoip::NET_TYPE_3G;
        case OngoingCallNetworkTypeCellularLte:
            return tgvoip::NET_TYPE_LTE;
        default:
            return tgvoip::NET_TYPE_WIFI;
    }
}

static int callControllerDataSavingForType(OngoingCallDataSaving type) {
    switch (type) {
        case OngoingCallDataSavingNever:
            return tgvoip::DATA_SAVING_NEVER;
        case OngoingCallDataSavingCellular:
            return tgvoip::DATA_SAVING_MOBILE;
        case OngoingCallDataSavingAlways:
            return tgvoip::DATA_SAVING_ALWAYS;
        default:
            return tgvoip::DATA_SAVING_NEVER;
    }
}

@implementation OngoingCallThreadLocalContext

+ (void)setupLoggingFunction:(void (*)(NSString *))loggingFunction {
    TGVoipLoggingFunction = loggingFunction;
}

+ (void)applyServerConfig:(NSString *)string {
    if (string.length != 0) {
        tgvoip::ServerConfig::GetSharedInstance()->Update(std::string(string.UTF8String));
    }
}

+ (int32_t)maxLayer {
    return tgvoip::VoIPController::GetConnectionMaxLayer();
}

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueue> _Nonnull)queue proxy:(VoipProxyServer * _Nullable)proxy networkType:(OngoingCallNetworkType)networkType dataSaving:(OngoingCallDataSaving)dataSaving derivedState:(NSData * _Nonnull)derivedState {
    self = [super init];
    if (self != nil) {
        _queue = queue;
        assert([queue isCurrent]);
        _contextId = addContext(self, queue);
        
        _callReceiveTimeout = 20.0;
        _callRingTimeout = 90.0;
        _callConnectTimeout = 30.0;
        _callPacketTimeout = 10.0;
        _dataSavingMode = callControllerDataSavingForType(dataSaving);
        _networkType = networkType;
        
        _controller = new tgvoip::VoIPController();
        _controller->implData = (void *)((intptr_t)_contextId);
        std::vector<uint8_t> derivedStateValue;
        derivedStateValue.resize(derivedState.length);
        [derivedState getBytes:derivedStateValue.data() length:derivedState.length];
        _controller->SetPersistentState(derivedStateValue);
        
        if (proxy != nil) {
            _controller->SetProxy(tgvoip::PROXY_SOCKS5, proxy.host.UTF8String, (uint16_t)proxy.port, proxy.username.UTF8String ?: "", proxy.password.UTF8String ?: "");
        }
        
        auto callbacks = tgvoip::VoIPController::Callbacks();
        callbacks.connectionStateChanged = &controllerStateCallback;
        callbacks.groupCallKeyReceived = NULL;
        callbacks.groupCallKeySent = NULL;
        callbacks.signalBarCountChanged = &signalBarsCallback;
        callbacks.upgradeToGroupCallRequested = NULL;
        _controller->SetCallbacks(callbacks);
        
        tgvoip::VoIPController::crypto.sha1 = &TGCallSha1;
        tgvoip::VoIPController::crypto.sha256 = &TGCallSha256;
        tgvoip::VoIPController::crypto.rand_bytes = &TGCallRandomBytes;
        tgvoip::VoIPController::crypto.aes_ige_encrypt = &TGCallAesIgeEncrypt;
        tgvoip::VoIPController::crypto.aes_ige_decrypt = &TGCallAesIgeDecrypt;
        tgvoip::VoIPController::crypto.aes_ctr_encrypt = &TGCallAesCtrEncrypt;
        
        _state = OngoingCallStateInitializing;
        _signalBars = -1;
    }
    return self;
}

- (void)dealloc {
    assert([_queue isCurrent]);
    removeContext(_contextId);
    if (_controller != NULL) {
        [self stop:nil];
    }
}

- (void)startWithKey:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing primaryConnection:(OngoingCallConnectionDescription * _Nonnull)primaryConnection alternativeConnections:(NSArray<OngoingCallConnectionDescription *> * _Nonnull)alternativeConnections maxLayer:(int32_t)maxLayer allowP2P:(BOOL)allowP2P logPath:(NSString * _Nonnull)logPath {
    std::vector<tgvoip::Endpoint> endpoints;
    NSArray<OngoingCallConnectionDescription *> *connections = [@[primaryConnection] arrayByAddingObjectsFromArray:alternativeConnections];
    for (OngoingCallConnectionDescription *connection in connections) {
        struct in_addr addrIpV4;
        if (!inet_aton(connection.ip.UTF8String, &addrIpV4)) {
            NSLog(@"CallSession: invalid ipv4 address");
        }
        
        struct in6_addr addrIpV6;
        if (!inet_pton(AF_INET6, connection.ipv6.UTF8String, &addrIpV6)) {
            NSLog(@"CallSession: invalid ipv6 address");
        }
        
        tgvoip::IPv4Address address(std::string(connection.ip.UTF8String));
        tgvoip::IPv6Address addressv6(std::string(connection.ipv6.UTF8String));
        unsigned char peerTag[16];
        [connection.peerTag getBytes:peerTag length:16];
        endpoints.push_back(tgvoip::Endpoint(connection.connectionId, (uint16_t)connection.port, address, addressv6, tgvoip::Endpoint::Type::UDP_RELAY, peerTag));
    }
    
    tgvoip::VoIPController::Config config(_callConnectTimeout, _callPacketTimeout, _dataSavingMode, false, true, true);
    config.logFilePath = logPath.length > 0 ? std::string(logPath.UTF8String) : "";
    config.statsDumpFilePath = "";
    
    if (_controller != nil) {
        _controller->SetConfig(config);
        
        _controller->SetNetworkType(callControllerNetworkTypeForType(_networkType));
        _controller->SetEncryptionKey((char *)key.bytes, isOutgoing);
        _controller->SetRemoteEndpoints(endpoints, allowP2P, maxLayer);
        _controller->Start();
        
        _controller->Connect();
    }
}

- (void)stop:(void (^)(NSString *, int64_t, int64_t, int64_t, int64_t))completion {
    if (_controller != nil) {
        _controller->Stop();
        
        auto debugString = _controller->GetDebugLog();
        NSString *debugLog = [NSString stringWithUTF8String:debugString.c_str()];
        
        tgvoip::VoIPController::TrafficStats stats;
        _controller->GetStats(&stats);
        std::vector<uint8_t> derivedStateValue = _controller->GetPersistentState();
        _lastDerivedState = [[NSData alloc] initWithBytes:derivedStateValue.data() length:derivedStateValue.size()];
        delete _controller;
        _controller = NULL;
        
        if (completion) {
            completion(debugLog, stats.bytesSentWifi, stats.bytesRecvdWifi, stats.bytesSentMobile, stats.bytesRecvdMobile);
        }
    }
}
    
- (bool)needRate {
    if (_controller != nil) {
        return _controller->NeedRate();
    } else {
        return false;
    }
}

- (NSString *)debugInfo {
    if (_controller != nil) {
        auto rawDebugString = _controller->GetDebugString();
        return [NSString stringWithUTF8String:rawDebugString.c_str()];
    } else {
        return nil;
    }
}

- (NSString *)version {
    if (_controller != nil) {
        return [NSString stringWithUTF8String:_controller->GetVersion()];
    } else {
        return nil;
    }
}

- (NSData * _Nonnull)getDerivedState {
    if (_controller != nil) {
        std::vector<uint8_t> derivedStateValue = _controller->GetPersistentState();
        return [[NSData alloc] initWithBytes:derivedStateValue.data() length:derivedStateValue.size()];
    } else if (_lastDerivedState != nil) {
        return _lastDerivedState;
    } else {
        return [NSData data];
    }
}

- (void)controllerStateChanged:(int)state {
    OngoingCallState callState = OngoingCallStateInitializing;
    switch (state) {
        case tgvoip::STATE_ESTABLISHED:
            callState = OngoingCallStateConnected;
            break;
        case tgvoip::STATE_FAILED:
            callState = OngoingCallStateFailed;
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
    if (_controller != nil) {
        _controller->SetMicMute(isMuted);
    }
}

- (void)setNetworkType:(OngoingCallNetworkType)networkType {
    if (_networkType != networkType) {
        _networkType = networkType;
        if (_controller != nil) {
            _controller->SetNetworkType(callControllerNetworkTypeForType(networkType));
        }
    }
}

@end
