#ifndef WEBRTC_IOS
#import "OngoingCallThreadLocalContext.h"
#else
#import <TgVoip/OngoingCallThreadLocalContext.h>
#endif


#import "Instance.h"
#import "InstanceImpl.h"
#import "VideoCaptureInterface.h"

#ifndef WEBRTC_IOS
#import "platform/darwin/VideoMetalViewMac.h"
#define GLVideoView VideoMetalView
#define UIViewContentModeScaleAspectFill kCAGravityResizeAspectFill
#else
#import "platform/darwin/VideoMetalView.h"
#import "platform/darwin/GLVideoView.h"
#endif

@implementation OngoingCallConnectionDescriptionWebrtc

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

@interface OngoingCallThreadLocalContextVideoCapturer () {
    std::shared_ptr<tgcalls::VideoCaptureInterface> _interface;
}

@end

@interface VideoMetalView (VideoViewImpl) <OngoingCallThreadLocalContextWebrtcVideoView>

@end

@implementation VideoMetalView (VideoViewImpl)

@end

@interface GLVideoView (VideoViewImpl) <OngoingCallThreadLocalContextWebrtcVideoView>

@end

@implementation GLVideoView (VideoViewImpl)

@end

@implementation OngoingCallThreadLocalContextVideoCapturer

- (instancetype _Nonnull)init {
    self = [super init];
    if (self != nil) {
        _interface = tgcalls::VideoCaptureInterface::Create();
    }
    return self;
}

- (void)switchVideoCamera {
    _interface->switchCamera();
}

- (void)setIsVideoEnabled:(bool)isVideoEnabled {
    _interface->setIsVideoEnabled(isVideoEnabled);
}

- (std::shared_ptr<tgcalls::VideoCaptureInterface>)getInterface {
    return _interface;
}

- (void)makeOutgoingVideoView:(void (^_Nonnull)(UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable))completion {
    std::shared_ptr<tgcalls::VideoCaptureInterface> interface = _interface;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([VideoMetalView isSupported]) {
            VideoMetalView *remoteRenderer = [[VideoMetalView alloc] initWithFrame:CGRectZero];
            remoteRenderer.videoContentMode = UIViewContentModeScaleAspectFill;
            
            std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
            interface->setVideoOutput(sink);
            
            completion(remoteRenderer);
        } else {
            GLVideoView *remoteRenderer = [[GLVideoView alloc] initWithFrame:CGRectZero];
            
            std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
            interface->setVideoOutput(sink);
            
            completion(remoteRenderer);
        }
    });
}

@end

@interface OngoingCallThreadLocalContextWebrtc () {
    id<OngoingCallThreadLocalContextQueueWebrtc> _queue;
    int32_t _contextId;

    OngoingCallNetworkTypeWebrtc _networkType;
    NSTimeInterval _callReceiveTimeout;
    NSTimeInterval _callRingTimeout;
    NSTimeInterval _callConnectTimeout;
    NSTimeInterval _callPacketTimeout;
    
    std::unique_ptr<tgcalls::Instance> _tgVoip;
    
    OngoingCallStateWebrtc _state;
    OngoingCallVideoStateWebrtc _videoState;
    bool _connectedOnce;
    OngoingCallRemoteVideoStateWebrtc _remoteVideoState;
    OngoingCallThreadLocalContextVideoCapturer *_videoCapturer;
    
    int32_t _signalBars;
    NSData *_lastDerivedState;
    
    void (^_sendSignalingData)(NSData *);
}

- (void)controllerStateChanged:(tgcalls::State)state videoState:(OngoingCallVideoStateWebrtc)videoState;
- (void)signalBarsChanged:(int32_t)signalBars;

@end

@implementation VoipProxyServerWebrtc

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

@implementation VoipRtcServerWebrtc

- (instancetype _Nonnull)initWithHost:(NSString * _Nonnull)host port:(int32_t)port username:(NSString * _Nullable)username password:(NSString * _Nullable)password isTurn:(bool)isTurn {
    self = [super init];
    if (self != nil) {
        _host = host;
        _port = port;
        _username = username;
        _password = password;
        _isTurn = isTurn;
    }
    return self;
}

@end

static tgcalls::NetworkType callControllerNetworkTypeForType(OngoingCallNetworkTypeWebrtc type) {
    switch (type) {
    case OngoingCallNetworkTypeWifi:
        return tgcalls::NetworkType::WiFi;
    case OngoingCallNetworkTypeCellularGprs:
        return tgcalls::NetworkType::Gprs;
    case OngoingCallNetworkTypeCellular3g:
        return tgcalls::NetworkType::ThirdGeneration;
    case OngoingCallNetworkTypeCellularLte:
        return tgcalls::NetworkType::Lte;
    default:
        return tgcalls::NetworkType::ThirdGeneration;
    }
}

static tgcalls::DataSaving callControllerDataSavingForType(OngoingCallDataSavingWebrtc type) {
    switch (type) {
    case OngoingCallDataSavingNever:
        return tgcalls::DataSaving::Never;
    case OngoingCallDataSavingCellular:
        return tgcalls::DataSaving::Mobile;
    case OngoingCallDataSavingAlways:
        return tgcalls::DataSaving::Always;
    default:
        return tgcalls::DataSaving::Never;
    }
}

@implementation OngoingCallThreadLocalContextWebrtc

static void (*InternalVoipLoggingFunction)(NSString *) = NULL;

+ (void)setupLoggingFunction:(void (*)(NSString *))loggingFunction {
    InternalVoipLoggingFunction = loggingFunction;
    tgcalls::SetLoggingFunction([](std::string const &string) {
        if (InternalVoipLoggingFunction) {
            InternalVoipLoggingFunction([[NSString alloc] initWithUTF8String:string.c_str()]);
        }
    });
}

+ (void)applyServerConfig:(NSString *)string {
    if (string.length != 0) {
        //TgVoip::setGlobalServerConfig(std::string(string.UTF8String));
    }
}

+ (int32_t)maxLayer {
    return 92;
}

+ (NSString *)version {
    return @"2.7.7";
}

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue proxy:(VoipProxyServerWebrtc * _Nullable)proxy rtcServers:(NSArray<VoipRtcServerWebrtc *> * _Nonnull)rtcServers networkType:(OngoingCallNetworkTypeWebrtc)networkType dataSaving:(OngoingCallDataSavingWebrtc)dataSaving derivedState:(NSData * _Nonnull)derivedState key:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing primaryConnection:(OngoingCallConnectionDescriptionWebrtc * _Nonnull)primaryConnection alternativeConnections:(NSArray<OngoingCallConnectionDescriptionWebrtc *> * _Nonnull)alternativeConnections maxLayer:(int32_t)maxLayer allowP2P:(BOOL)allowP2P logPath:(NSString * _Nonnull)logPath sendSignalingData:(void (^)(NSData * _Nonnull))sendSignalingData videoCapturer:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer {
    self = [super init];
    if (self != nil) {
        _queue = queue;
        assert([queue isCurrent]);
        
        _callReceiveTimeout = 20.0;
        _callRingTimeout = 90.0;
        _callConnectTimeout = 30.0;
        _callPacketTimeout = 10.0;
        _networkType = networkType;
        _sendSignalingData = [sendSignalingData copy];
        _videoCapturer = videoCapturer;
        if (videoCapturer != nil) {
            _videoState = OngoingCallVideoStateOutgoingRequested;
            _remoteVideoState = OngoingCallRemoteVideoStateActive;
        } else {
            _videoState = OngoingCallVideoStatePossible;
            _remoteVideoState = OngoingCallRemoteVideoStateInactive;
        }
        
        std::vector<uint8_t> derivedStateValue;
        derivedStateValue.resize(derivedState.length);
        [derivedState getBytes:derivedStateValue.data() length:derivedState.length];
        
        std::unique_ptr<tgcalls::Proxy> proxyValue = nullptr;
        if (proxy != nil) {
            tgcalls::Proxy *proxyObject = new tgcalls::Proxy();
            proxyObject->host = proxy.host.UTF8String;
            proxyObject->port = (uint16_t)proxy.port;
            proxyObject->login = proxy.username.UTF8String ?: "";
            proxyObject->password = proxy.password.UTF8String ?: "";
            proxyValue = std::unique_ptr<tgcalls::Proxy>(proxyObject);
        }
        
        std::vector<tgcalls::RtcServer> parsedRtcServers;
        for (VoipRtcServerWebrtc *server in rtcServers) {
            parsedRtcServers.push_back((tgcalls::RtcServer){
                .host = server.host.UTF8String,
                .port = (uint16_t)server.port,
                .login = server.username.UTF8String,
                .password = server.password.UTF8String,
                .isTurn = server.isTurn
            });
        }
        
        /*TgVoipCrypto crypto;
        crypto.sha1 = &TGCallSha1;
        crypto.sha256 = &TGCallSha256;
        crypto.rand_bytes = &TGCallRandomBytes;
        crypto.aes_ige_encrypt = &TGCallAesIgeEncrypt;
        crypto.aes_ige_decrypt = &TGCallAesIgeDecrypt;
        crypto.aes_ctr_encrypt = &TGCallAesCtrEncrypt;*/
        
        std::vector<tgcalls::Endpoint> endpoints;
        NSArray<OngoingCallConnectionDescriptionWebrtc *> *connections = [@[primaryConnection] arrayByAddingObjectsFromArray:alternativeConnections];
        for (OngoingCallConnectionDescriptionWebrtc *connection in connections) {
            unsigned char peerTag[16];
            [connection.peerTag getBytes:peerTag length:16];
            
            tgcalls::Endpoint endpoint;
            endpoint.endpointId = connection.connectionId;
            endpoint.host = {
                .ipv4 = std::string(connection.ip.UTF8String),
                .ipv6 = std::string(connection.ipv6.UTF8String)
            };
            endpoint.port = (uint16_t)connection.port;
            endpoint.type = tgcalls::EndpointType::UdpRelay;
            memcpy(endpoint.peerTag, peerTag, 16);
            endpoints.push_back(endpoint);
        }
        
        tgcalls::Config config = {
            .initializationTimeout = _callConnectTimeout,
            .receiveTimeout = _callPacketTimeout,
            .dataSaving = callControllerDataSavingForType(dataSaving),
            .enableP2P = (bool)allowP2P,
            .enableAEC = false,
            .enableNS = true,
            .enableAGC = true,
            .enableCallUpgrade = false,
            .logPath = logPath.length == 0 ? "" : std::string(logPath.UTF8String),
            .maxApiLayer = [OngoingCallThreadLocalContextWebrtc maxLayer]
        };
        
        std::vector<uint8_t> encryptionKeyValue;
        encryptionKeyValue.resize(key.length);
        memcpy(encryptionKeyValue.data(), key.bytes, key.length);
        
        tgcalls::EncryptionKey encryptionKey(encryptionKeyValue, isOutgoing);
        
        __weak OngoingCallThreadLocalContextWebrtc *weakSelf = self;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            tgcalls::Register<tgcalls::InstanceImpl>();
        });
        _tgVoip = tgcalls::Meta::Create("2.7.7", (tgcalls::Descriptor){
            .config = config,
            .persistentState = (tgcalls::PersistentState){ derivedStateValue },
            .endpoints = endpoints,
            .proxy = std::move(proxyValue),
            .rtcServers = parsedRtcServers,
            .initialNetworkType = callControllerNetworkTypeForType(networkType),
            .encryptionKey = encryptionKey,
            .videoCapture = [_videoCapturer getInterface],
            .stateUpdated = [weakSelf, queue](tgcalls::State state, tgcalls::VideoState videoState) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        OngoingCallVideoStateWebrtc mappedVideoState;
                        switch (videoState) {
                            case tgcalls::VideoState::Possible:
                                mappedVideoState = OngoingCallVideoStatePossible;
                                break;
                            case tgcalls::VideoState::OutgoingRequested:
                                mappedVideoState = OngoingCallVideoStateOutgoingRequested;
                                break;
                            case tgcalls::VideoState::IncomingRequested:
                                mappedVideoState = OngoingCallVideoStateIncomingRequested;
                                break;
                            case tgcalls::VideoState::Active:
                                mappedVideoState = OngoingCallVideoStateActive;
                                break;
                        }
                        
                        [strongSelf controllerStateChanged:state videoState:mappedVideoState];
                    }
                }];
            },
            .signalBarsUpdated = [](int value) {
                
            },
            .remoteVideoIsActiveUpdated = [weakSelf, queue](bool isActive) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        OngoingCallRemoteVideoStateWebrtc remoteVideoState;
                        if (isActive) {
                            remoteVideoState = OngoingCallRemoteVideoStateActive;
                        } else {
                            remoteVideoState = OngoingCallRemoteVideoStateInactive;
                        }
                        if (strongSelf->_remoteVideoState != remoteVideoState) {
                            strongSelf->_remoteVideoState = remoteVideoState;
                            if (strongSelf->_stateChanged) {
                                strongSelf->_stateChanged(strongSelf->_state, strongSelf->_videoState, strongSelf->_remoteVideoState);
                            }
                        }
                    }
                }];
            },
            .signalingDataEmitted = [weakSelf, queue](const std::vector<uint8_t> &data) {
                NSData *mappedData = [[NSData alloc] initWithBytes:data.data() length:data.size()];
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        [strongSelf signalingDataEmitted:mappedData];
                    }
                }];
            }
        });
        
        _state = OngoingCallStateInitializing;
        _signalBars = -1;
    }
    return self;
}

- (void)dealloc {
    assert([_queue isCurrent]);
    if (_tgVoip != NULL) {
        [self stop:nil];
    }
}

- (bool)needRate {
    return false;
}

- (void)stop:(void (^)(NSString *, int64_t, int64_t, int64_t, int64_t))completion {
    if (_tgVoip) {
        tgcalls::FinalState finalState = _tgVoip->stop();
        
        NSString *debugLog = [NSString stringWithUTF8String:finalState.debugLog.c_str()];
        _lastDerivedState = [[NSData alloc] initWithBytes:finalState.persistentState.value.data() length:finalState.persistentState.value.size()];
        
        if (completion) {
            completion(debugLog, finalState.trafficStats.bytesSentWifi, finalState.trafficStats.bytesReceivedWifi, finalState.trafficStats.bytesSentMobile, finalState.trafficStats.bytesReceivedMobile);
        }
    }
}

- (NSString *)debugInfo {
    if (_tgVoip != nullptr) {
        NSString *version = [self version];
        return [NSString stringWithFormat:@"WebRTC, Version: %@", version];
        //auto rawDebugString = _tgVoip->getDebugInfo();
        //return [NSString stringWithUTF8String:rawDebugString.c_str()];
    } else {
        return nil;
    }
}

- (NSString *)version {
    return @"2.7.7";
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

- (void)controllerStateChanged:(tgcalls::State)state videoState:(OngoingCallVideoStateWebrtc)videoState {
    OngoingCallStateWebrtc callState = OngoingCallStateInitializing;
    switch (state) {
        case tgcalls::State::Established:
            callState = OngoingCallStateConnected;
            break;
        case tgcalls::State::Failed:
            callState = OngoingCallStateFailed;
            break;
        case tgcalls::State::Reconnecting:
            callState = OngoingCallStateReconnecting;
            break;
        default:
            break;
    }
    
    if (_state != callState || _videoState != videoState) {
        _state = callState;
        _videoState = videoState;
        
        if (_stateChanged) {
            _stateChanged(_state, _videoState, _remoteVideoState);
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

- (void)signalingDataEmitted:(NSData *)data {
    if (_sendSignalingData) {
        _sendSignalingData(data);
    }
}

- (void)addSignalingData:(NSData *)data {
    if (_tgVoip) {
        std::vector<uint8_t> mappedData;
        mappedData.resize(data.length);
        [data getBytes:mappedData.data() length:data.length];
        _tgVoip->receiveSignalingData(mappedData);
    }
}

- (void)setIsMuted:(bool)isMuted {
    if (_tgVoip) {
        _tgVoip->setMuteMicrophone(isMuted);
    }
}

- (void)setNetworkType:(OngoingCallNetworkTypeWebrtc)networkType {
    if (_networkType != networkType) {
        _networkType = networkType;
        if (_tgVoip) {
            _tgVoip->setNetworkType(callControllerNetworkTypeForType(networkType));
        }
    }
}

- (void)makeIncomingVideoView:(void (^_Nonnull)(UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable))completion {
    if (_tgVoip) {
        __weak OngoingCallThreadLocalContextWebrtc *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([VideoMetalView isSupported]) {
                VideoMetalView *remoteRenderer = [[VideoMetalView alloc] initWithFrame:CGRectZero];
                remoteRenderer.videoContentMode = UIViewContentModeScaleAspectFill;
                
                std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
                __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                if (strongSelf) {
                    strongSelf->_tgVoip->setIncomingVideoOutput(sink);
                }
                
                completion(remoteRenderer);
            } else {
                GLVideoView *remoteRenderer = [[GLVideoView alloc] initWithFrame:CGRectZero];
                
                std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
                __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                if (strongSelf) {
                    strongSelf->_tgVoip->setIncomingVideoOutput(sink);
                }
                
                completion(remoteRenderer);
            }
        });
    }
}

- (void)requestVideo:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer {
    if (_tgVoip && _videoCapturer == nil) {
        _videoCapturer = videoCapturer;
        _tgVoip->requestVideo([_videoCapturer getInterface]);
    }
}

- (void)acceptVideo:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer {
    if (_tgVoip && _videoCapturer == nil) {
        _videoCapturer = videoCapturer;
        _tgVoip->requestVideo([_videoCapturer getInterface]);
    }
}

@end
