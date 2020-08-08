#ifndef WEBRTC_IOS
#import "OngoingCallThreadLocalContext.h"
#else
#import <TgVoip/OngoingCallThreadLocalContext.h>
#endif


#import "Instance.h"
#import "InstanceImpl.h"
#import "reference/InstanceImplReference.h"

#import "VideoCaptureInterface.h"

#ifndef WEBRTC_IOS
#import "platform/darwin/VideoMetalViewMac.h"
#define GLVideoView VideoMetalView
#define UIViewContentModeScaleAspectFill kCAGravityResizeAspectFill
#define UIViewContentModeScaleAspectFit kCAGravityResizeAspect

#else
#import "platform/darwin/VideoMetalView.h"
#import "platform/darwin/GLVideoView.h"
#endif

@implementation OngoingCallConnectionDescriptionWebrtc

- (instancetype _Nonnull)initWithConnectionId:(int64_t)connectionId hasStun:(bool)hasStun hasTurn:(bool)hasTurn ip:(NSString * _Nonnull)ip port:(int32_t)port username:(NSString * _Nonnull)username password:(NSString * _Nonnull)password {
    self = [super init];
    if (self != nil) {
        _connectionId = connectionId;
        _hasStun = hasStun;
        _hasTurn = hasTurn;
        _ip = ip;
        _port = port;
        _username = username;
        _password = password;
    }
    return self;
}

@end

@interface OngoingCallThreadLocalContextVideoCapturer () {
    std::shared_ptr<tgcalls::VideoCaptureInterface> _interface;
}

@end

@protocol OngoingCallThreadLocalContextWebrtcVideoViewImpl <NSObject>

@property (nonatomic, readwrite) OngoingCallVideoOrientationWebrtc orientation;

@end

@interface VideoMetalView (VideoViewImpl) <OngoingCallThreadLocalContextWebrtcVideoView, OngoingCallThreadLocalContextWebrtcVideoViewImpl>

@property (nonatomic, readwrite) OngoingCallVideoOrientationWebrtc orientation;

@end

@implementation VideoMetalView (VideoViewImpl)

- (OngoingCallVideoOrientationWebrtc)orientation {
    return (OngoingCallVideoOrientationWebrtc)self.internalOrientation;
}

- (void)setOrientation:(OngoingCallVideoOrientationWebrtc)orientation {
    [self setInternalOrientation:(int)orientation];
}

- (void)setOnOrientationUpdated:(void (^ _Nullable)(OngoingCallVideoOrientationWebrtc))onOrientationUpdated {
    if (onOrientationUpdated) {
        [self internalSetOnOrientationUpdated:^(int value) {
            onOrientationUpdated((OngoingCallVideoOrientationWebrtc)value);
        }];
    } else {
        [self internalSetOnOrientationUpdated:nil];
    }
}

- (void)setOnIsMirroredUpdated:(void (^ _Nullable)(bool))onIsMirroredUpdated {
    if (onIsMirroredUpdated) {
        [self internalSetOnIsMirroredUpdated:^(bool value) {
            onIsMirroredUpdated(value);
        }];
    } else {
        [self internalSetOnIsMirroredUpdated:nil];
    }
}

@end

@interface GLVideoView (VideoViewImpl) <OngoingCallThreadLocalContextWebrtcVideoView, OngoingCallThreadLocalContextWebrtcVideoViewImpl>

@property (nonatomic, readwrite) OngoingCallVideoOrientationWebrtc orientation;

@end

@implementation GLVideoView (VideoViewImpl)

- (OngoingCallVideoOrientationWebrtc)orientation {
    return (OngoingCallVideoOrientationWebrtc)self.internalOrientation;
}

- (void)setOrientation:(OngoingCallVideoOrientationWebrtc)orientation {
    [self setInternalOrientation:(int)orientation];
}

- (void)setOnOrientationUpdated:(void (^ _Nullable)(OngoingCallVideoOrientationWebrtc))onOrientationUpdated {
    if (onOrientationUpdated) {
        [self internalSetOnOrientationUpdated:^(int value) {
            onOrientationUpdated((OngoingCallVideoOrientationWebrtc)value);
        }];
    } else {
        [self internalSetOnOrientationUpdated:nil];
    }
}

- (void)setOnIsMirroredUpdated:(void (^ _Nullable)(bool))onIsMirroredUpdated {
    if (onIsMirroredUpdated) {
        [self internalSetOnIsMirroredUpdated:^(bool value) {
            onIsMirroredUpdated(value);
        }];
    } else {
        [self internalSetOnIsMirroredUpdated:nil];
    }
}

@end

@implementation OngoingCallThreadLocalContextVideoCapturer

- (instancetype _Nonnull)init {
    self = [super init];
    if (self != nil) {
        _interface = tgcalls::VideoCaptureInterface::Create();
    }
    return self;
}

- (void)dealloc {
}

- (void)switchVideoCamera {
    _interface->switchCamera();
}

- (void)setIsVideoEnabled:(bool)isVideoEnabled {
    _interface->setState(isVideoEnabled ? tgcalls::VideoState::Active : tgcalls::VideoState::Paused);
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
            interface->setOutput(sink);
            
            completion(remoteRenderer);
        } else {
            GLVideoView *remoteRenderer = [[GLVideoView alloc] initWithFrame:CGRectZero];
            
            std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
            interface->setOutput(sink);
            
            completion(remoteRenderer);
        }
    });
}

@end

@interface OngoingCallThreadLocalContextWebrtcTerminationResult : NSObject

@property (nonatomic, readonly) tgcalls::FinalState finalState;

@end

@implementation OngoingCallThreadLocalContextWebrtcTerminationResult

- (instancetype)initWithFinalState:(tgcalls::FinalState)finalState {
    self = [super init];
    if (self != nil) {
        _finalState = finalState;
    }
    return self;
}

@end

@interface OngoingCallThreadLocalContextWebrtc () {
    NSString *_version;
    id<OngoingCallThreadLocalContextQueueWebrtc> _queue;
    int32_t _contextId;

    OngoingCallNetworkTypeWebrtc _networkType;
    NSTimeInterval _callReceiveTimeout;
    NSTimeInterval _callRingTimeout;
    NSTimeInterval _callConnectTimeout;
    NSTimeInterval _callPacketTimeout;
    
    std::unique_ptr<tgcalls::Instance> _tgVoip;
    OngoingCallThreadLocalContextWebrtcTerminationResult *_terminationResult;
    
    OngoingCallStateWebrtc _state;
    OngoingCallVideoStateWebrtc _videoState;
    bool _connectedOnce;
    OngoingCallRemoteBatteryLevelWebrtc _remoteBatteryLevel;
    OngoingCallRemoteVideoStateWebrtc _remoteVideoState;
    OngoingCallRemoteAudioStateWebrtc _remoteAudioState;
    OngoingCallVideoOrientationWebrtc _remoteVideoOrientation;
    __weak UIView<OngoingCallThreadLocalContextWebrtcVideoViewImpl> *_currentRemoteVideoRenderer;
    OngoingCallThreadLocalContextVideoCapturer *_videoCapturer;
    
    int32_t _signalBars;
    NSData *_lastDerivedState;
    
    void (^_sendSignalingData)(NSData *);
    
    float _remotePreferredAspectRatio;

}

- (void)controllerStateChanged:(tgcalls::State)state;
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

+ (NSArray<NSString *> * _Nonnull)versionsWithIncludeReference:(bool)includeReference {
    if (includeReference) {
        return @[@"2.7.7", @"2.8.8"];
    } else {
        return @[@"2.7.7"];
    }
}

- (instancetype _Nonnull)initWithVersion:(NSString * _Nonnull)version queue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue proxy:(VoipProxyServerWebrtc * _Nullable)proxy networkType:(OngoingCallNetworkTypeWebrtc)networkType dataSaving:(OngoingCallDataSavingWebrtc)dataSaving derivedState:(NSData * _Nonnull)derivedState key:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing connections:(NSArray<OngoingCallConnectionDescriptionWebrtc *> * _Nonnull)connections maxLayer:(int32_t)maxLayer allowP2P:(BOOL)allowP2P logPath:(NSString * _Nonnull)logPath sendSignalingData:(void (^)(NSData * _Nonnull))sendSignalingData videoCapturer:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer preferredAspectRatio:(float)preferredAspectRatio enableHighBitrateVideoCalls:(bool)enableHighBitrateVideoCalls {
    self = [super init];
    if (self != nil) {
        _version = version;
        _queue = queue;
        assert([queue isCurrent]);
        
        assert([[OngoingCallThreadLocalContextWebrtc versionsWithIncludeReference:true] containsObject:version]);
        
        _callReceiveTimeout = 20.0;
        _callRingTimeout = 90.0;
        _callConnectTimeout = 30.0;
        _callPacketTimeout = 10.0;
        _remotePreferredAspectRatio = 0;
        _networkType = networkType;
        _sendSignalingData = [sendSignalingData copy];
        _videoCapturer = videoCapturer;
        if (videoCapturer != nil) {
            _videoState = OngoingCallVideoStateActive;
        } else {
            _videoState = OngoingCallVideoStateInactive;
        }
        _remoteVideoState = OngoingCallRemoteVideoStateInactive;
        _remoteAudioState = OngoingCallRemoteAudioStateActive;
        
        _remoteVideoOrientation = OngoingCallVideoOrientation0;
        
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
        for (OngoingCallConnectionDescriptionWebrtc *connection in connections) {
            if (connection.hasStun) {
                parsedRtcServers.push_back((tgcalls::RtcServer){
                    .host = connection.ip.UTF8String,
                    .port = (uint16_t)connection.port,
                    .login = "",
                    .password = "",
                    .isTurn = false
                });
            }
            if (connection.hasTurn) {
                parsedRtcServers.push_back((tgcalls::RtcServer){
                    .host = connection.ip.UTF8String,
                    .port = (uint16_t)connection.port,
                    .login = connection.username.UTF8String,
                    .password = connection.password.UTF8String,
                    .isTurn = true
                });
            }
        }
        
        std::vector<tgcalls::Endpoint> endpoints;
        
        tgcalls::Config config = {
            .initializationTimeout = _callConnectTimeout,
            .receiveTimeout = _callPacketTimeout,
            .dataSaving = callControllerDataSavingForType(dataSaving),
            .enableP2P = (bool)allowP2P,
            .enableAEC = false,
            .enableNS = true,
            .enableAGC = true,
            .enableCallUpgrade = false,
            .logPath = "", //logPath.length == 0 ? "" : std::string(logPath.UTF8String),
            .maxApiLayer = [OngoingCallThreadLocalContextWebrtc maxLayer],
            .preferredAspectRatio = preferredAspectRatio,
            .enableHighBitrateVideo = enableHighBitrateVideoCalls
        };
        
        auto encryptionKeyValue = std::make_shared<std::array<uint8_t, 256>>();
        memcpy(encryptionKeyValue->data(), key.bytes, key.length);
        
        tgcalls::EncryptionKey encryptionKey(encryptionKeyValue, isOutgoing);
        
        __weak OngoingCallThreadLocalContextWebrtc *weakSelf = self;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            tgcalls::Register<tgcalls::InstanceImpl>();
            tgcalls::Register<tgcalls::InstanceImplReference>();
        });
        _tgVoip = tgcalls::Meta::Create([version UTF8String], (tgcalls::Descriptor){
            .config = config,
            .persistentState = (tgcalls::PersistentState){ derivedStateValue },
            .endpoints = endpoints,
            .proxy = std::move(proxyValue),
            .rtcServers = parsedRtcServers,
            .initialNetworkType = callControllerNetworkTypeForType(networkType),
            .encryptionKey = encryptionKey,
            .videoCapture = [_videoCapturer getInterface],
            .stateUpdated = [weakSelf, queue](tgcalls::State state) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        [strongSelf controllerStateChanged:state];
                    }
                }];
            },
            .signalBarsUpdated = [weakSelf, queue](int value) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        strongSelf->_signalBars = value;
                        if (strongSelf->_signalBarsChanged) {
                            strongSelf->_signalBarsChanged(value);
                        }
                    }
                }];
            },
            .remoteMediaStateUpdated = [weakSelf, queue](tgcalls::AudioState audioState, tgcalls::VideoState videoState) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        OngoingCallRemoteAudioStateWebrtc remoteAudioState;
                        OngoingCallRemoteVideoStateWebrtc remoteVideoState;
                        switch (audioState) {
                            case tgcalls::AudioState::Muted:
                                remoteAudioState = OngoingCallRemoteAudioStateMuted;
                                break;
                            case tgcalls::AudioState::Active:
                                remoteAudioState = OngoingCallRemoteAudioStateActive;
                                break;
                            default:
                                remoteAudioState = OngoingCallRemoteAudioStateMuted;
                                break;
                        }
                        switch (videoState) {
                            case tgcalls::VideoState::Inactive:
                                remoteVideoState = OngoingCallRemoteVideoStateInactive;
                                break;
                            case tgcalls::VideoState::Paused:
                                remoteVideoState = OngoingCallRemoteVideoStatePaused;
                                break;
                            case tgcalls::VideoState::Active:
                                remoteVideoState = OngoingCallRemoteVideoStateActive;
                                break;
                            default:
                                remoteVideoState = OngoingCallRemoteVideoStateInactive;
                                break;
                        }
                        if (strongSelf->_remoteVideoState != remoteVideoState || strongSelf->_remoteAudioState != remoteAudioState) {
                            strongSelf->_remoteVideoState = remoteVideoState;
                            strongSelf->_remoteAudioState = remoteAudioState;
                            if (strongSelf->_stateChanged) {
                                strongSelf->_stateChanged(strongSelf->_state, strongSelf->_videoState, strongSelf->_remoteVideoState, strongSelf->_remoteAudioState, strongSelf->_remoteBatteryLevel, strongSelf->_remotePreferredAspectRatio);
                            }
                        }
                    }
                }];
            },
            .remoteBatteryLevelIsLowUpdated = [weakSelf, queue](bool isLow) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        OngoingCallRemoteBatteryLevelWebrtc remoteBatteryLevel;
                        if (isLow) {
                            remoteBatteryLevel = OngoingCallRemoteBatteryLevelLow;
                        } else {
                            remoteBatteryLevel = OngoingCallRemoteBatteryLevelNormal;
                        }
                        if (strongSelf->_remoteBatteryLevel != remoteBatteryLevel) {
                            strongSelf->_remoteBatteryLevel = remoteBatteryLevel;
                            if (strongSelf->_stateChanged) {
                                strongSelf->_stateChanged(strongSelf->_state, strongSelf->_videoState, strongSelf->_remoteVideoState, strongSelf->_remoteAudioState, strongSelf->_remoteBatteryLevel, strongSelf->_remotePreferredAspectRatio);
                            }
                        }
                    }
                }];
            },
            .remotePrefferedAspectRatioUpdated = [weakSelf, queue](float value) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        strongSelf->_remotePreferredAspectRatio = value;
                        if (strongSelf->_stateChanged) {
                            strongSelf->_stateChanged(strongSelf->_state, strongSelf->_videoState, strongSelf->_remoteVideoState, strongSelf->_remoteAudioState, strongSelf->_remoteBatteryLevel, strongSelf->_remotePreferredAspectRatio);
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
        _signalBars = 4;
    }
    return self;
}

- (void)dealloc {
    if (InternalVoipLoggingFunction) {
        InternalVoipLoggingFunction(@"OngoingCallThreadLocalContext: dealloc");
    }
    
    assert([_queue isCurrent]);
    if (_tgVoip != NULL) {
        [self stop:nil];
    }
}

- (bool)needRate {
    return false;
}

- (void)stopInstanceIfNeeded {
    if (!_tgVoip) {
        return;
    }
    tgcalls::FinalState finalState = _tgVoip->stop();
    _tgVoip.reset();
    _terminationResult = [[OngoingCallThreadLocalContextWebrtcTerminationResult alloc] initWithFinalState:finalState];
}

- (void)beginTermination {
    [self stopInstanceIfNeeded];
}

- (void)stop:(void (^)(NSString *, int64_t, int64_t, int64_t, int64_t))completion {
    [self stopInstanceIfNeeded];
    
    if (completion) {
        if (_terminationResult) {
            NSString *debugLog = [NSString stringWithUTF8String:_terminationResult.finalState.debugLog.c_str()];
            _lastDerivedState = [[NSData alloc] initWithBytes:_terminationResult.finalState.persistentState.value.data() length:_terminationResult.finalState.persistentState.value.size()];
            
            if (completion) {
                completion(debugLog, _terminationResult.finalState.trafficStats.bytesSentWifi, _terminationResult.finalState.trafficStats.bytesReceivedWifi, _terminationResult.finalState.trafficStats.bytesSentMobile, _terminationResult.finalState.trafficStats.bytesReceivedMobile);
            }
        } else {
            if (completion) {
                completion(@"", 0, 0, 0, 0);
            }
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
    return _version;
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

- (void)controllerStateChanged:(tgcalls::State)state {
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
    
    if (_state != callState) {
        _state = callState;
        
        if (_stateChanged) {
            _stateChanged(_state, _videoState, _remoteVideoState, _remoteAudioState, _remoteBatteryLevel, _remotePreferredAspectRatio);
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

- (void)setIsLowBatteryLevel:(bool)isLowBatteryLevel {
    if (_tgVoip) {
        _tgVoip->setIsLowBatteryLevel(isLowBatteryLevel);
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
                #if TARGET_OS_IPHONE
                remoteRenderer.videoContentMode = UIViewContentModeScaleAspectFill;
                #else
                remoteRenderer.videoContentMode = UIViewContentModeScaleAspect;
                #endif
                
                std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
                __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                if (strongSelf) {
                    [remoteRenderer setOrientation:strongSelf->_remoteVideoOrientation];
                    strongSelf->_currentRemoteVideoRenderer = remoteRenderer;
                    strongSelf->_tgVoip->setIncomingVideoOutput(sink);
                }
                
                completion(remoteRenderer);
            } else {
                GLVideoView *remoteRenderer = [[GLVideoView alloc] initWithFrame:CGRectZero];
                
                std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
                __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                if (strongSelf) {
                    [remoteRenderer setOrientation:strongSelf->_remoteVideoOrientation];
                    strongSelf->_currentRemoteVideoRenderer = remoteRenderer;
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
        _tgVoip->setVideoCapture([_videoCapturer getInterface]);
        
        _videoState = OngoingCallVideoStateActive;
        if (_stateChanged) {
            _stateChanged(_state, _videoState, _remoteVideoState, _remoteAudioState, _remoteBatteryLevel, _remotePreferredAspectRatio);
        }
    }
}

- (void)disableVideo {
    if (_tgVoip) {
        _videoCapturer = nil;
        _tgVoip->setVideoCapture(nullptr);
        
        _videoState = OngoingCallVideoStateInactive;
        if (_stateChanged) {
            _stateChanged(_state, _videoState, _remoteVideoState, _remoteAudioState, _remoteBatteryLevel, _remotePreferredAspectRatio);
        }
    }
}

- (void)remotePrefferedAspectRatioUpdated:(float)remotePrefferedAspectRatio {
    
}

@end
