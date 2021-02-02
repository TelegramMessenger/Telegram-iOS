#ifndef WEBRTC_IOS
#import "OngoingCallThreadLocalContext.h"
#else
#import <TgVoipWebrtc/OngoingCallThreadLocalContext.h>
#endif

#import "Instance.h"
#import "InstanceImpl.h"
#import "reference/InstanceImplReference.h"

#import "VideoCaptureInterface.h"

#ifndef WEBRTC_IOS
#import "platform/darwin/VideoMetalViewMac.h"
#import "platform/darwin/GLVideoViewMac.h"
#define UIViewContentModeScaleAspectFill kCAGravityResizeAspectFill
#define UIViewContentModeScaleAspect kCAGravityResizeAspect

#else
#import "platform/darwin/VideoMetalView.h"
#import "platform/darwin/GLVideoView.h"
#endif

#import "group/GroupInstanceImpl.h"
#import "group/GroupInstanceCustomImpl.h"

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
@property (nonatomic, readonly) CGFloat aspect;

@end

@interface VideoMetalView (VideoViewImpl) <OngoingCallThreadLocalContextWebrtcVideoView, OngoingCallThreadLocalContextWebrtcVideoViewImpl>

@property (nonatomic, readwrite) OngoingCallVideoOrientationWebrtc orientation;
@property (nonatomic, readonly) CGFloat aspect;

@end

@implementation VideoMetalView (VideoViewImpl)

- (OngoingCallVideoOrientationWebrtc)orientation {
    return (OngoingCallVideoOrientationWebrtc)self.internalOrientation;
}

- (CGFloat)aspect {
    return self.internalAspect;
}

- (void)setOrientation:(OngoingCallVideoOrientationWebrtc)orientation {
    [self setInternalOrientation:(int)orientation];
}

- (void)setOnOrientationUpdated:(void (^ _Nullable)(OngoingCallVideoOrientationWebrtc, CGFloat))onOrientationUpdated {
    if (onOrientationUpdated) {
        [self internalSetOnOrientationUpdated:^(int value, CGFloat aspect) {
            onOrientationUpdated((OngoingCallVideoOrientationWebrtc)value, aspect);
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
@property (nonatomic, readonly) CGFloat aspect;

@end

@implementation GLVideoView (VideoViewImpl)

- (OngoingCallVideoOrientationWebrtc)orientation {
    return (OngoingCallVideoOrientationWebrtc)self.internalOrientation;
}

- (CGFloat)aspect {
    return self.internalAspect;
}

- (void)setOrientation:(OngoingCallVideoOrientationWebrtc)orientation {
    [self setInternalOrientation:(int)orientation];
}

- (void)setOnOrientationUpdated:(void (^ _Nullable)(OngoingCallVideoOrientationWebrtc, CGFloat))onOrientationUpdated {
    if (onOrientationUpdated) {
        [self internalSetOnOrientationUpdated:^(int value, CGFloat aspect) {
            onOrientationUpdated((OngoingCallVideoOrientationWebrtc)value, aspect);
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

@interface OngoingCallThreadLocalContextVideoCapturer () {
    bool _keepLandscape;
}

@end

@implementation OngoingCallThreadLocalContextVideoCapturer

- (instancetype _Nonnull)initWithDeviceId:(NSString * _Nonnull)deviceId keepLandscape:(bool)keepLandscape {
    self = [super init];
    if (self != nil) {
        _keepLandscape = keepLandscape;
        
        std::string resolvedId = deviceId.UTF8String;
        if (keepLandscape) {
            resolvedId += std::string(":landscape");
        }
        _interface = tgcalls::VideoCaptureInterface::Create(resolvedId);
    }
    return self;
}


- (void)dealloc {
}

- (void)switchVideoInput:(NSString * _Nonnull)deviceId {
    std::string resolvedId = deviceId.UTF8String;
    if (_keepLandscape) {
        resolvedId += std::string(":landscape");
    }
    _interface->switchToDevice(resolvedId);
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
#ifndef WEBRTC_IOS
            remoteRenderer.videoContentMode = UIViewContentModeScaleAspectFill;
#endif

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
    bool _didStop;
    
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

+ (NSArray<NSString *> * _Nonnull)versionsWithIncludeReference:(bool)__unused includeReference {
    return @[@"2.7.7", @"3.0.0"];
}

+ (tgcalls::ProtocolVersion)protocolVersionFromLibraryVersion:(NSString *)version {
    if ([version isEqualToString:@"2.7.7"]) {
        return tgcalls::ProtocolVersion::V0;
    } else if ([version isEqualToString:@"3.0.0"]) {
        return tgcalls::ProtocolVersion::V1;
    } else {
        return tgcalls::ProtocolVersion::V0;
    }
}

- (instancetype _Nonnull)initWithVersion:(NSString * _Nonnull)version queue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue proxy:(VoipProxyServerWebrtc * _Nullable)proxy networkType:(OngoingCallNetworkTypeWebrtc)networkType dataSaving:(OngoingCallDataSavingWebrtc)dataSaving derivedState:(NSData * _Nonnull)derivedState key:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing connections:(NSArray<OngoingCallConnectionDescriptionWebrtc *> * _Nonnull)connections maxLayer:(int32_t)maxLayer allowP2P:(BOOL)allowP2P allowTCP:(BOOL)allowTCP enableStunMarking:(BOOL)enableStunMarking logPath:(NSString * _Nonnull)logPath statsLogPath:(NSString * _Nonnull)statsLogPath sendSignalingData:(void (^)(NSData * _Nonnull))sendSignalingData videoCapturer:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer preferredVideoCodec:(NSString * _Nullable)preferredVideoCodec audioInputDeviceId: (NSString * _Nonnull)audioInputDeviceId {
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
        
        std::vector<std::string> preferredVideoCodecs;
        if (preferredVideoCodec != nil) {
            preferredVideoCodecs.push_back([preferredVideoCodec UTF8String]);
        }
        
        std::vector<tgcalls::Endpoint> endpoints;
        
        tgcalls::Config config = {
            .initializationTimeout = _callConnectTimeout,
            .receiveTimeout = _callPacketTimeout,
            .dataSaving = callControllerDataSavingForType(dataSaving),
            .enableP2P = (bool)allowP2P,
            .allowTCP = (bool)allowTCP,
            .enableStunMarking = (bool)enableStunMarking,
            .enableAEC = false,
            .enableNS = true,
            .enableAGC = true,
            .enableCallUpgrade = false,
            .logPath = logPath.length == 0 ? "" : std::string(logPath.UTF8String),
            .statsLogPath = statsLogPath.length == 0 ? "" : std::string(statsLogPath.UTF8String),
            .maxApiLayer = [OngoingCallThreadLocalContextWebrtc maxLayer],
            .enableHighBitrateVideo = true,
            .preferredVideoCodecs = preferredVideoCodecs,
            .protocolVersion = [OngoingCallThreadLocalContextWebrtc protocolVersionFromLibraryVersion:version]
        };
        
        auto encryptionKeyValue = std::make_shared<std::array<uint8_t, 256>>();
        memcpy(encryptionKeyValue->data(), key.bytes, key.length);
        
        tgcalls::EncryptionKey encryptionKey(encryptionKeyValue, isOutgoing);
        
        __weak OngoingCallThreadLocalContextWebrtc *weakSelf = self;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            tgcalls::Register<tgcalls::InstanceImpl>();
        });
        
        
        
        _tgVoip = tgcalls::Meta::Create([version UTF8String], (tgcalls::Descriptor){
            .config = config,
            .persistentState = (tgcalls::PersistentState){ derivedStateValue },
            .endpoints = endpoints,
            .proxy = std::move(proxyValue),
            .rtcServers = parsedRtcServers,
            .initialNetworkType = callControllerNetworkTypeForType(networkType),
            .encryptionKey = encryptionKey,
            .mediaDevicesConfig = tgcalls::MediaDevicesConfig {
                .audioInputId = [audioInputDeviceId UTF8String],
                .audioOutputId = [@"" UTF8String]
            },
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
            .audioLevelUpdated = [weakSelf, queue](float level) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        if (strongSelf->_audioLevelUpdated) {
                            strongSelf->_audioLevelUpdated(level);
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
    
    if (_tgVoip != NULL) {
        [self stop:nil];
    }
}

- (bool)needRate {
    return false;
}

- (void)beginTermination {
}

+ (void)stopWithTerminationResult:(OngoingCallThreadLocalContextWebrtcTerminationResult *)terminationResult completion:(void (^)(NSString *, int64_t, int64_t, int64_t, int64_t))completion {
    if (completion) {
        if (terminationResult) {
            NSString *debugLog = [NSString stringWithUTF8String:terminationResult.finalState.debugLog.c_str()];
            
            if (completion) {
                completion(debugLog, terminationResult.finalState.trafficStats.bytesSentWifi, terminationResult.finalState.trafficStats.bytesReceivedWifi, terminationResult.finalState.trafficStats.bytesSentMobile, terminationResult.finalState.trafficStats.bytesReceivedMobile);
            }
        } else {
            if (completion) {
                completion(@"", 0, 0, 0, 0);
            }
        }
    }
}

- (void)stop:(void (^)(NSString *, int64_t, int64_t, int64_t, int64_t))completion {
    if (!_tgVoip) {
        return;
    }
    if (completion == nil) {
        if (!_didStop) {
            _tgVoip->stop([](tgcalls::FinalState finalState) {
            });
        }
        _tgVoip.reset();
        return;
    }
    
    __weak OngoingCallThreadLocalContextWebrtc *weakSelf = self;
    id<OngoingCallThreadLocalContextQueueWebrtc> queue = _queue;
    _didStop = true;
    _tgVoip->stop([weakSelf, queue, completion = [completion copy]](tgcalls::FinalState finalState) {
        [queue dispatch:^{
            __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
            if (strongSelf) {
                strongSelf->_tgVoip.reset();
            }
            
            OngoingCallThreadLocalContextWebrtcTerminationResult *terminationResult = [[OngoingCallThreadLocalContextWebrtcTerminationResult alloc] initWithFinalState:finalState];
            
            [OngoingCallThreadLocalContextWebrtc stopWithTerminationResult:terminationResult completion:completion];
        }];
    });
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
                remoteRenderer.videoContentMode = UIViewContentModeScaleToFill;
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

- (void)setRequestedVideoAspect:(float)aspect {
    if (_tgVoip) {
        _tgVoip->setRequestedVideoAspect(aspect);
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

- (void)switchAudioOutput:(NSString * _Nonnull)deviceId {
    _tgVoip->setAudioOutputDevice(deviceId.UTF8String);
}
- (void)switchAudioInput:(NSString * _Nonnull)deviceId {
    _tgVoip->setAudioInputDevice(deviceId.UTF8String);
}

@end


@interface GroupCallThreadLocalContext () {
    id<OngoingCallThreadLocalContextQueueWebrtc> _queue;
    
    std::unique_ptr<tgcalls::GroupInstanceInterface> _instance;
    OngoingCallThreadLocalContextVideoCapturer *_videoCapturer;
    
    void (^_networkStateUpdated)(GroupCallNetworkState);
}

@end

@implementation GroupCallThreadLocalContext

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue networkStateUpdated:(void (^ _Nonnull)(GroupCallNetworkState))networkStateUpdated audioLevelsUpdated:(void (^ _Nonnull)(NSArray<NSNumber *> * _Nonnull))audioLevelsUpdated inputDeviceId:(NSString * _Nonnull)inputDeviceId outputDeviceId:(NSString * _Nonnull)outputDeviceId videoCapturer:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer incomingVideoSourcesUpdated:(void (^ _Nonnull)(NSArray<NSNumber *> * _Nonnull))incomingVideoSourcesUpdated participantDescriptionsRequired:(void (^ _Nonnull)(NSArray<NSNumber *> * _Nonnull))participantDescriptionsRequired {
    self = [super init];
    if (self != nil) {
        _queue = queue;
        
        _networkStateUpdated = [networkStateUpdated copy];
        _videoCapturer = videoCapturer;
        
        __weak GroupCallThreadLocalContext *weakSelf = self;
        _instance.reset(new tgcalls::GroupInstanceCustomImpl((tgcalls::GroupInstanceDescriptor){
            .networkStateUpdated = [weakSelf, queue, networkStateUpdated](bool isConnected) {
                [queue dispatch:^{
                    __strong GroupCallThreadLocalContext *strongSelf = weakSelf;
                    if (strongSelf == nil) {
                        return;
                    }
                    networkStateUpdated(isConnected ? GroupCallNetworkStateConnected : GroupCallNetworkStateConnecting);
                }];
            },
            .audioLevelsUpdated = [audioLevelsUpdated](tgcalls::GroupLevelsUpdate const &levels) {
                NSMutableArray *result = [[NSMutableArray alloc] init];
                for (auto &it : levels.updates) {
                    [result addObject:@(it.ssrc)];
                    [result addObject:@(it.value.level)];
                    [result addObject:@(it.value.voice)];
                }
                audioLevelsUpdated(result);
            },
            .initialInputDeviceId = inputDeviceId.UTF8String,
            .initialOutputDeviceId = outputDeviceId.UTF8String,
            .videoCapture = [_videoCapturer getInterface],
            .incomingVideoSourcesUpdated = [incomingVideoSourcesUpdated](std::vector<uint32_t> const &ssrcs) {
                NSMutableArray<NSNumber *> *mappedSources = [[NSMutableArray alloc] init];
                for (auto it : ssrcs) {
                    [mappedSources addObject:@(it)];
                }
                incomingVideoSourcesUpdated(mappedSources);
            },
            .participantDescriptionsRequired = [participantDescriptionsRequired](std::vector<uint32_t> const &ssrcs) {
                NSMutableArray<NSNumber *> *mappedSources = [[NSMutableArray alloc] init];
                for (auto it : ssrcs) {
                    [mappedSources addObject:@(it)];
                }
                participantDescriptionsRequired(mappedSources);
            }
        }));
    }
    return self;
}

- (void)stop {
    if (_instance) {
        _instance->stop();
        _instance.reset();
    }
}

static void processJoinPayload(tgcalls::GroupJoinPayload &payload, void (^ _Nonnull completion)(NSString * _Nonnull, uint32_t)) {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    int32_t signedSsrc = *(int32_t *)&payload.ssrc;
    
    dict[@"ssrc"] = @(signedSsrc);
    dict[@"ufrag"] = [NSString stringWithUTF8String:payload.ufrag.c_str()];
    dict[@"pwd"] = [NSString stringWithUTF8String:payload.pwd.c_str()];
    
    NSMutableArray *fingerprints = [[NSMutableArray alloc] init];
    for (auto &fingerprint : payload.fingerprints) {
        [fingerprints addObject:@{
            @"hash": [NSString stringWithUTF8String:fingerprint.hash.c_str()],
            @"fingerprint": [NSString stringWithUTF8String:fingerprint.fingerprint.c_str()],
            @"setup": [NSString stringWithUTF8String:fingerprint.setup.c_str()]
        }];
    }
    
    dict[@"fingerprints"] = fingerprints;
    
    NSMutableArray *parsedVideoSsrcGroups = [[NSMutableArray alloc] init];
    NSMutableArray *parsedVideoSources = [[NSMutableArray alloc] init];
    for (auto &group : payload.videoSourceGroups) {
        NSMutableDictionary *parsedGroup = [[NSMutableDictionary alloc] init];
        parsedGroup[@"semantics"] = [NSString stringWithUTF8String:group.semantics.c_str()];
        NSMutableArray *sources = [[NSMutableArray alloc] init];
        for (auto &source : group.ssrcs) {
            [sources addObject:@(source)];
            if (![parsedVideoSources containsObject:@(source)]) {
                [parsedVideoSources addObject:@(source)];
            }
        }
        parsedGroup[@"sources"] = sources;
        [parsedVideoSsrcGroups addObject:parsedGroup];
    }
    if (parsedVideoSsrcGroups.count != 0) {
        dict[@"ssrc-groups"] = parsedVideoSsrcGroups;
    }
    
    NSMutableArray *videoPayloadTypes = [[NSMutableArray alloc] init];
    for (auto &payloadType : payload.videoPayloadTypes) {
        NSMutableDictionary *parsedType = [[NSMutableDictionary alloc] init];
        parsedType[@"id"] = @(payloadType.id);
        NSString *name = [NSString stringWithUTF8String:payloadType.name.c_str()];
        parsedType[@"name"] = name;
        parsedType[@"clockrate"] = @(payloadType.clockrate);
        if (![name isEqualToString:@"rtx"]) {
            parsedType[@"channels"] = @(payloadType.channels);
        }
        
        NSMutableDictionary *parsedParameters = [[NSMutableDictionary alloc] init];
        for (auto &it : payloadType.parameters) {
            NSString *key = [NSString stringWithUTF8String:it.first.c_str()];
            NSString *value = [NSString stringWithUTF8String:it.second.c_str()];
            parsedParameters[key] = value;
        }
        if (parsedParameters.count != 0) {
            parsedType[@"parameters"] = parsedParameters;
        }
        
        if (![name isEqualToString:@"rtx"]) {
            NSMutableArray *parsedFbs = [[NSMutableArray alloc] init];
            for (auto &it : payloadType.feedbackTypes) {
                NSMutableDictionary *parsedFb = [[NSMutableDictionary alloc] init];
                parsedFb[@"type"] = [NSString stringWithUTF8String:it.type.c_str()];
                if (it.subtype.size() != 0) {
                    parsedFb[@"subtype"] = [NSString stringWithUTF8String:it.subtype.c_str()];
                }
                [parsedFbs addObject:parsedFb];
            }
            parsedType[@"rtcp-fbs"] = parsedFbs;
        }
        
        [videoPayloadTypes addObject:parsedType];
    }
    if (videoPayloadTypes.count != 0) {
        dict[@"payload-types"] = videoPayloadTypes;
    }
    
    NSMutableArray *parsedExtensions = [[NSMutableArray alloc] init];
    for (auto &it : payload.videoExtensionMap) {
        NSMutableDictionary *parsedExtension = [[NSMutableDictionary alloc] init];
        parsedExtension[@"id"] = @(it.first);
        parsedExtension[@"uri"] = [NSString stringWithUTF8String:it.second.c_str()];
        [parsedExtensions addObject:parsedExtension];
    }
    if (parsedExtensions.count != 0) {
        dict[@"rtp-hdrexts"] = parsedExtensions;
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    completion(string, payload.ssrc);
}

- (void)emitJoinPayload:(void (^ _Nonnull)(NSString * _Nonnull, uint32_t))completion {
    if (_instance) {
        _instance->emitJoinPayload([completion](tgcalls::GroupJoinPayload payload) {
            processJoinPayload(payload, completion);
        });
    }
}

- (void)setJoinResponsePayload:(NSString * _Nonnull)payload participants:(NSArray<OngoingGroupCallParticipantDescription *> * _Nonnull)participants {
    tgcalls::GroupJoinResponsePayload result;
    
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    if (payloadData == nil) {
        return;
    }
    
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil];
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    NSDictionary *transport = dict[@"transport"];
    if (![transport isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    NSString *pwd = transport[@"pwd"];
    if (![pwd isKindOfClass:[NSString class]]) {
        return;
    }
    
    NSString *ufrag = transport[@"ufrag"];
    if (![ufrag isKindOfClass:[NSString class]]) {
        return;
    }
    
    result.pwd = [pwd UTF8String];
    result.ufrag = [ufrag UTF8String];
    
    NSArray *fingerprintsValue = transport[@"fingerprints"];
    if (![fingerprintsValue isKindOfClass:[NSArray class]]) {
        //return;
    }
    
    for (NSDictionary *fingerprintValue in fingerprintsValue) {
        if (![fingerprintValue isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *hashValue = fingerprintValue[@"hash"];
        if (![hashValue isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *fingerprint = fingerprintValue[@"fingerprint"];
        if (![fingerprint isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *setup = fingerprintValue[@"setup"];
        if (![setup isKindOfClass:[NSString class]]) {
            continue;
        }
        tgcalls::GroupJoinPayloadFingerprint parsed;
        parsed.fingerprint = [fingerprint UTF8String];
        parsed.setup = [setup UTF8String];
        parsed.hash = [hashValue UTF8String];
        result.fingerprints.push_back(parsed);
    }
    
    NSArray *candidatesValue = transport[@"candidates"];
    if (![candidatesValue isKindOfClass:[NSArray class]]) {
        return;
    }
    
    for (NSDictionary *candidateValue in candidatesValue) {
        if (![candidateValue isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        
        NSString *portValue = candidateValue[@"port"];
        if (![portValue isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *protocolValue = candidateValue[@"protocol"];
        if (![protocolValue isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *networkValue = candidateValue[@"network"];
        if (![networkValue isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *generationValue = candidateValue[@"generation"];
        if (![generationValue isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *idValue = candidateValue[@"id"];
        if (![idValue isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *componentValue = candidateValue[@"component"];
        if (![componentValue isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *foundationValue = candidateValue[@"foundation"];
        if (![foundationValue isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *priorityValue = candidateValue[@"priority"];
        if (![priorityValue isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *ipValue = candidateValue[@"ip"];
        if (![ipValue isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *typeValue = candidateValue[@"type"];
        if (![typeValue isKindOfClass:[NSString class]]) {
            continue;
        }
        
        NSString *tcpTypeValue = candidateValue[@"tcptype"];
        if (![tcpTypeValue isKindOfClass:[NSString class]]) {
            tcpTypeValue = @"";
        }
        NSString *relAddrValue = candidateValue[@"rel-addr"];
        if (![relAddrValue isKindOfClass:[NSString class]]) {
            relAddrValue = @"";
        }
        NSString *relPortValue = candidateValue[@"rel-port"];
        if (![relPortValue isKindOfClass:[NSString class]]) {
            relPortValue = @"";
        }
        
        tgcalls::GroupJoinResponseCandidate candidate;
        
        candidate.port = [portValue UTF8String];
        candidate.protocol = [protocolValue UTF8String];
        candidate.network = [networkValue UTF8String];
        candidate.generation = [generationValue UTF8String];
        candidate.id = [idValue UTF8String];
        candidate.component = [componentValue UTF8String];
        candidate.foundation = [foundationValue UTF8String];
        candidate.priority = [priorityValue UTF8String];
        candidate.ip = [ipValue UTF8String];
        candidate.type = [typeValue UTF8String];
        
        candidate.tcpType = [tcpTypeValue UTF8String];
        candidate.relAddr = [relAddrValue UTF8String];
        candidate.relPort = [relPortValue UTF8String];
        
        result.candidates.push_back(candidate);
    }
    
    std::vector<tgcalls::GroupParticipantDescription> parsedParticipants;
    for (OngoingGroupCallParticipantDescription *participant in participants) {
        tgcalls::GroupParticipantDescription parsedParticipant;
        parsedParticipant.audioSsrc = participant.audioSsrc;
        
        if (participant.jsonParams.length != 0) {
            [self parseJsonIntoParticipant:participant.jsonParams participant:parsedParticipant];
        }
        parsedParticipants.push_back(parsedParticipant);
    }
    
    if (_instance) {
        _instance->setJoinResponsePayload(result, std::move(parsedParticipants));
    }
}

- (void)removeSsrcs:(NSArray<NSNumber *> * _Nonnull)ssrcs {
    if (_instance) {
        std::vector<uint32_t> values;
        for (NSNumber *ssrc in ssrcs) {
            values.push_back([ssrc unsignedIntValue]);
        }
        _instance->removeSsrcs(values);
    }
}

- (void)parseJsonIntoParticipant:(NSString *)payload participant:(tgcalls::GroupParticipantDescription &)participant {
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    if (payloadData == nil) {
        return;
    }
    
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil];
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    NSString *endpointId = dict[@"endpoint"];
    if (![endpointId isKindOfClass:[NSString class]]) {
        return;
    }
    
    participant.endpointId = [endpointId UTF8String];
    
    NSArray *ssrcGroups = dict[@"ssrc-groups"];
    if ([ssrcGroups isKindOfClass:[NSArray class]]) {
        for (NSDictionary *group in ssrcGroups) {
            if (![group isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSString *semantics = group[@"semantics"];
            if (![semantics isKindOfClass:[NSString class]]) {
                continue;
            }
            NSArray *sources = group[@"sources"];
            if (![sources isKindOfClass:[NSArray class]]) {
                continue;
            }
            tgcalls::GroupJoinPayloadVideoSourceGroup groupDesc;
            for (NSNumber *nSsrc in sources) {
                if ([nSsrc isKindOfClass:[NSNumber class]]) {
                    groupDesc.ssrcs.push_back([nSsrc unsignedIntValue]);
                }
            }
            groupDesc.semantics = [semantics UTF8String];
            participant.videoSourceGroups.push_back(groupDesc);
        }
    }
    
    NSArray *hdrExts = dict[@"rtp-hdrexts"];
    if ([hdrExts isKindOfClass:[NSArray class]]) {
        for (NSDictionary *extDict in hdrExts) {
            if (![extDict isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSNumber *nId = extDict[@"id"];
            if (![nId isKindOfClass:[NSNumber class]]) {
                continue;
            }
            NSString *uri = extDict[@"uri"];
            if (![uri isKindOfClass:[NSString class]]) {
                continue;
            }
            participant.videoExtensionMap.push_back(std::make_pair((uint32_t)[nId unsignedIntValue], (std::string)[uri UTF8String]));
        }
    }
    
    NSArray *payloadTypes = dict[@"payload-types"];
    if ([payloadTypes isKindOfClass:[NSArray class]]) {
        for (NSDictionary *payloadDict in payloadTypes) {
            if (![payloadDict isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSNumber *nId = payloadDict[@"id"];
            if (![nId isKindOfClass:[NSNumber class]]) {
                continue;
            }
            NSNumber *nClockrate = payloadDict[@"clockrate"];
            if (nClockrate != nil && ![nClockrate isKindOfClass:[NSNumber class]]) {
                continue;
            }
            NSNumber *nChannels = payloadDict[@"channels"];
            if (nChannels != nil && ![nChannels isKindOfClass:[NSNumber class]]) {
                continue;
            }
            NSString *name = payloadDict[@"name"];
            if (![name isKindOfClass:[NSString class]]) {
                continue;
            }
            
            tgcalls::GroupJoinPayloadVideoPayloadType parsedPayload;
            parsedPayload.id = [nId unsignedIntValue];
            parsedPayload.clockrate = [nClockrate unsignedIntValue];
            parsedPayload.channels = [nChannels unsignedIntValue];
            parsedPayload.name = [name UTF8String];
            
            NSArray *fbs = payloadDict[@"rtcp-fbs"];
            if ([fbs isKindOfClass:[NSArray class]]) {
                for (NSDictionary *fbDict in fbs) {
                    if (![fbDict isKindOfClass:[NSDictionary class]]) {
                        continue;
                    }
                    NSString *type = fbDict[@"type"];
                    if (![type isKindOfClass:[NSString class]]) {
                        continue;
                    }
                    
                    NSString *subtype = fbDict[@"subtype"];
                    if (subtype != nil && ![subtype isKindOfClass:[NSString class]]) {
                        continue;
                    }
                    
                    tgcalls::GroupJoinPayloadVideoPayloadFeedbackType parsedFeedback;
                    parsedFeedback.type = [type UTF8String];
                    if (subtype != nil) {
                        parsedFeedback.subtype = [subtype UTF8String];
                    }
                    parsedPayload.feedbackTypes.push_back(parsedFeedback);
                }
            }
            
            NSDictionary *parameters = payloadDict[@"parameters"];
            if ([parameters isKindOfClass:[NSDictionary class]]) {
                for (NSString *nKey in parameters) {
                    if (![nKey isKindOfClass:[NSString class]]) {
                        continue;
                    }
                    NSString *value = parameters[nKey];
                    if (![value isKindOfClass:[NSString class]]) {
                        continue;
                    }
                    parsedPayload.parameters.push_back(std::make_pair((std::string)[nKey UTF8String], (std::string)[value UTF8String]));
                }
            }
            participant.videoPayloadTypes.push_back(parsedPayload);
        }
    }
}

- (void)addParticipants:(NSArray<OngoingGroupCallParticipantDescription *> * _Nonnull)participants {
    if (_instance) {
        std::vector<tgcalls::GroupParticipantDescription> parsedParticipants;
        for (OngoingGroupCallParticipantDescription *participant in participants) {
            tgcalls::GroupParticipantDescription parsedParticipant;
            parsedParticipant.audioSsrc = participant.audioSsrc;
            
            if (participant.jsonParams.length != 0) {
                [self parseJsonIntoParticipant:participant.jsonParams participant:parsedParticipant];
            }
            parsedParticipants.push_back(parsedParticipant);
        }
        _instance->addParticipants(std::move(parsedParticipants));
    }
}

- (void)setIsMuted:(bool)isMuted {
    if (_instance) {
        _instance->setIsMuted(isMuted);
    }
}

- (void)requestVideo:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer completion:(void (^ _Nonnull)(NSString * _Nonnull, uint32_t))completion {
    if (_instance) {
        _instance->setVideoCapture([videoCapturer getInterface], [completion](auto payload){
            processJoinPayload(payload, completion);
        });
    }
}

- (void)disableVideo:(void (^ _Nonnull)(NSString * _Nonnull, uint32_t))completion {
    if (_instance) {
        _instance->setVideoCapture(nullptr, [completion](auto payload){
            processJoinPayload(payload, completion);
        });
    }
}

- (void)setVolumeForSsrc:(uint32_t)ssrc volume:(double)volume {
    if (_instance) {
        _instance->setVolume(ssrc, volume);
    }
}

- (void)setFullSizeVideoSsrc:(uint32_t)ssrc {
    if (_instance) {
        _instance->setFullSizeVideoSsrc(ssrc);
    }
}

- (void)switchAudioOutput:(NSString * _Nonnull)deviceId {
    if (_instance) {
        _instance->setAudioOutputDevice(deviceId.UTF8String);
    }
}
- (void)switchAudioInput:(NSString * _Nonnull)deviceId {
    if (_instance) {
        _instance->setAudioInputDevice(deviceId.UTF8String);
    }
}

- (void)makeIncomingVideoViewWithSsrc:(uint32_t)ssrc completion:(void (^_Nonnull)(UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable))completion {
    if (_instance) {
        __weak GroupCallThreadLocalContext *weakSelf = self;
        id<OngoingCallThreadLocalContextQueueWebrtc> queue = _queue;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([VideoMetalView isSupported]) {
                VideoMetalView *remoteRenderer = [[VideoMetalView alloc] initWithFrame:CGRectZero];
#if TARGET_OS_IPHONE
                remoteRenderer.videoContentMode = UIViewContentModeScaleToFill;
#else
                remoteRenderer.videoContentMode = UIViewContentModeScaleAspect;
#endif
                
                std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
                
                [queue dispatch:^{
                    __strong GroupCallThreadLocalContext *strongSelf = weakSelf;
                    if (strongSelf && strongSelf->_instance) {
                        strongSelf->_instance->addIncomingVideoOutput(ssrc, sink);
                    }
                }];
                
                completion(remoteRenderer);
            } else {
                GLVideoView *remoteRenderer = [[GLVideoView alloc] initWithFrame:CGRectZero];
             //   [remoteRenderer setVideoContentMode:kCAGravityResizeAspectFill];
                std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
                
                [queue dispatch:^{
                    __strong GroupCallThreadLocalContext *strongSelf = weakSelf;
                    if (strongSelf && strongSelf->_instance) {
                        strongSelf->_instance->addIncomingVideoOutput(ssrc, sink);
                    }
                }];
                
                completion(remoteRenderer);
            }
        });
    }
}

@end

@implementation OngoingGroupCallParticipantDescription

- (instancetype _Nonnull)initWithAudioSsrc:(uint32_t)audioSsrc jsonParams:(NSString * _Nullable)jsonParams {
    self = [super init];
    if (self != nil) {
        _audioSsrc = audioSsrc;
        _jsonParams = jsonParams;
    }
    return self;
}

@end
