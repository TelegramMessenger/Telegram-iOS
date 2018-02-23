#import "OngoingCallThreadLocalContext.h"

#import "../../libtgvoip/VoIPController.h"
#import "../../libtgvoip/os/darwin/SetupLogging.h"

#import <MtProtoKitDynamic/MtProtoKitDynamic.h>

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

@interface OngoingCallThreadLocalContext () {
    NSTimeInterval _callReceiveTimeout;
    NSTimeInterval _callRingTimeout;
    NSTimeInterval _callConnectTimeout;
    NSTimeInterval _callPacketTimeout;
    int32_t _dataSavingMode;
    bool _allowP2P;
    
    tgvoip::VoIPController *_controller;
    
    OngoingCallState _state;
}

- (void)controllerStateChanged:(int)state;

@end

static void controllerStateCallback(tgvoip::VoIPController *controller, int state) {
    OngoingCallThreadLocalContext *context = (__bridge OngoingCallThreadLocalContext *)controller->implData;
    [context controllerStateChanged:state];
}

@implementation OngoingCallThreadLocalContext

+ (void)setupLoggingFunction:(void (*)(NSString *))loggingFunction {
    TGVoipLoggingFunction = loggingFunction;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _callReceiveTimeout = 20.0;
        _callRingTimeout = 90.0;
        _callConnectTimeout = 30.0;
        _callPacketTimeout = 10.0;
        _dataSavingMode = 0;
        _allowP2P = true;
        
        _controller = new tgvoip::VoIPController();
        _controller->implData = (__bridge void *)self;
        
        /*releasable*/
        //_controller->SetStateCallback(&controllerStateCallback);
        
        auto callbacks = tgvoip::VoIPController::Callbacks();
        callbacks.connectionStateChanged = &controllerStateCallback;
        callbacks.groupCallKeyReceived = NULL;
        callbacks.groupCallKeySent = NULL;
        callbacks.signalBarCountChanged = NULL;
        callbacks.upgradeToGroupCallRequested = NULL;
        _controller->SetCallbacks(callbacks);
        
        tgvoip::VoIPController::crypto.sha1 = &TGCallSha1;
        tgvoip::VoIPController::crypto.sha256 = &TGCallSha256;
        tgvoip::VoIPController::crypto.rand_bytes = &TGCallRandomBytes;
        tgvoip::VoIPController::crypto.aes_ige_encrypt = &TGCallAesIgeEncrypt;
        tgvoip::VoIPController::crypto.aes_ige_decrypt = &TGCallAesIgeDecrypt;
        tgvoip::VoIPController::crypto.aes_ctr_encrypt = &TGCallAesCtrEncrypt;
        
        _state = OngoingCallStateInitializing;
    }
    return self;
}

- (void)startWithKey:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing primaryConnection:(OngoingCallConnectionDescription * _Nonnull)primaryConnection alternativeConnections:(NSArray<OngoingCallConnectionDescription *> * _Nonnull)alternativeConnections maxLayer:(int32_t)maxLayer {
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
        endpoints.push_back(tgvoip::Endpoint(connection.connectionId, (uint16_t)connection.port, address, addressv6, tgvoip::Endpoint::TYPE_UDP_RELAY, peerTag));
        /*releasable*/
        //endpoints.push_back(tgvoip::Endpoint(connection.connectionId, (uint16_t)connection.port, address, addressv6, EP_TYPE_UDP_RELAY, peerTag));
    }
    
    voip_config_t config;
    config.init_timeout = _callConnectTimeout;
    config.recv_timeout = _callPacketTimeout;
    config.data_saving = _dataSavingMode;
    memset(config.logFilePath, 0, sizeof(config.logFilePath));
    config.enableAEC = false;
    config.enableNS = true;
    config.enableAGC = true;
    memset(config.statsDumpFilePath, 0, sizeof(config.statsDumpFilePath));
    
    _controller->SetConfig(&config);
    
    _controller->SetEncryptionKey((char *)key.bytes, isOutgoing);
    /*releasable*/
    _controller->SetRemoteEndpoints(endpoints, _allowP2P, 65);
    _controller->Start();
    
    _controller->Connect();
}

- (void)stop {
    if (_controller) {
        char *buffer = (char *)malloc(_controller->GetDebugLogLength());
        /*releasable*/
        _controller->Stop();
        _controller->GetDebugLog(buffer);
        NSString *debugLog = [[NSString alloc] initWithUTF8String:buffer];
        
        voip_stats_t stats;
        _controller->GetStats(&stats);
        delete _controller;
        _controller = NULL;
    }
    
    /*MTNetworkUsageManager *usageManager = [[MTNetworkUsageManager alloc] initWithInfo:[[TGTelegramNetworking instance] mediaUsageInfoForType:TGNetworkMediaTypeTagCall]];
    [usageManager addIncomingBytes:stats.bytesRecvdMobile interface:MTNetworkUsageManagerInterfaceWWAN];
    [usageManager addIncomingBytes:stats.bytesRecvdWifi interface:MTNetworkUsageManagerInterfaceOther];
    
    [usageManager addOutgoingBytes:stats.bytesSentMobile interface:MTNetworkUsageManagerInterfaceWWAN];
    [usageManager addOutgoingBytes:stats.bytesSentWifi interface:MTNetworkUsageManagerInterfaceOther];*/
    
    //if (sendDebugLog && self.peerId != 0 && self.accessHash != 0)
    //    [[TGCallSignals saveCallDebug:self.peerId accessHash:self.accessHash data:debugLog] startWithNext:nil];
}

- (void)controllerStateChanged:(int)state {
    OngoingCallState callState = OngoingCallStateInitializing;
    /*releasable*/
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
    /*switch (state) {
        case STATE_ESTABLISHED:
            callState = OngoingCallStateConnected;
            break;
        case STATE_FAILED:
            callState = OngoingCallStateFailed;
            break;
        default:
            break;
    }*/
    
    if (callState != _state) {
        _state = callState;
        
        if (_stateChanged) {
            _stateChanged(callState);
        }
    }
}

- (void)setIsMuted:(bool)isMuted {
    _controller->SetMicMute(isMuted);
}

@end
