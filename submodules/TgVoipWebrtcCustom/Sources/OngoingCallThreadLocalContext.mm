#import <TgVoip/OngoingCallThreadLocalContext.h>

#import <Foundation/Foundation.h>

#import "api/peerconnection/RTCPeerConnectionFactory.h"
#import "api/peerconnection/RTCSSLAdapter.h"
#import "api/peerconnection/RTCConfiguration.h"
#import "api/peerconnection/RTCIceServer.h"
#import "api/peerconnection/RTCPeerConnection.h"
#import "api/peerconnection/RTCMediaConstraints.h"
#import "api/peerconnection/RTCMediaStreamTrack.h"
#import "api/peerconnection/RTCAudioTrack.h"
#import "api/peerconnection/RTCVideoTrack.h"
#import "api/peerconnection/RTCRtpTransceiver.h"
#import "api/peerconnection/RTCSessionDescription.h"
#import "api/peerconnection/RTCIceCandidate.h"
#import "api/peerconnection/RTCMediaStream.h"
#import "components/video_codec/RTCDefaultVideoDecoderFactory.h"
#import "components/video_codec/RTCDefaultVideoEncoderFactory.h"
#import "components/audio/RTCAudioSession.h"
#import "base/RTCVideoCapturer.h"
#import "api/peerconnection/RTCVideoSource.h"
#import "components/capturer/RTCFileVideoCapturer.h"
#import "components/capturer/RTCCameraVideoCapturer.h"
#import "components/renderer/metal/RTCMTLVideoView.h"
#import "components/renderer/opengl/RTCEAGLVideoView.h"

#import "RtcConnection.h"

static void (*InternalVoipLoggingFunction)(NSString *) = NULL;

static void voipLog(NSString* format, ...) {
    va_list args;
    va_start(args, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    if (InternalVoipLoggingFunction) {
        InternalVoipLoggingFunction(string);
    }
}

@implementation OngoingCallConnectionDescriptionWebrtcCustom

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

@interface OngoingCallThreadLocalContextWebrtcCustom () {
    id<OngoingCallThreadLocalContextQueueWebrtcCustom> _queue;
    int32_t _contextId;
    
    bool _isOutgoing;
    void (^_sendSignalingData)(NSData * _Nonnull);

    OngoingCallNetworkTypeWebrtcCustom _networkType;
    NSTimeInterval _callReceiveTimeout;
    NSTimeInterval _callRingTimeout;
    NSTimeInterval _callConnectTimeout;
    NSTimeInterval _callPacketTimeout;
    
    OngoingCallStateWebrtcCustom _state;
    int32_t _signalBars;
    
    RtcConnection *_connection;
    
    bool _receivedRemoteDescription;
}

@end

@implementation VoipProxyServerWebrtcCustom

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

@implementation OngoingCallThreadLocalContextWebrtcCustom

+ (NSString *)version {
    return @"2.8.8";
}

+ (void)setupLoggingFunction:(void (*)(NSString *))loggingFunction {
    InternalVoipLoggingFunction = loggingFunction;
}

+ (void)applyServerConfig:(NSString * _Nullable)__unused data {
    
}

+ (int32_t)maxLayer {
    return 80;
}

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueueWebrtcCustom> _Nonnull)queue proxy:(VoipProxyServerWebrtcCustom * _Nullable)proxy networkType:(OngoingCallNetworkTypeWebrtcCustom)networkType dataSaving:(OngoingCallDataSavingWebrtcCustom)dataSaving derivedState:(NSData * _Nonnull)derivedState key:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing primaryConnection:(OngoingCallConnectionDescriptionWebrtcCustom * _Nonnull)primaryConnection alternativeConnections:(NSArray<OngoingCallConnectionDescriptionWebrtcCustom *> * _Nonnull)alternativeConnections maxLayer:(int32_t)maxLayer allowP2P:(BOOL)allowP2P logPath:(NSString * _Nonnull)logPath sendSignalingData:(void (^)(NSData * _Nonnull))sendSignalingData {
    self = [super init];
    if (self != nil) {
        _queue = queue;
        assert([queue isCurrent]);
        
        _isOutgoing = isOutgoing;
        _sendSignalingData = [sendSignalingData copy];
        
        _callReceiveTimeout = 20.0;
        _callRingTimeout = 90.0;
        _callConnectTimeout = 30.0;
        _callPacketTimeout = 10.0;
        _networkType = networkType;
        
        _state = OngoingCallStateInitializing;
        _signalBars = -1;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            RTCInitializeSSL();
        });
        
        [RTCAudioSession sharedInstance].useManualAudio = true;
        [RTCAudioSession sharedInstance].isAudioEnabled = true;
        
        __weak OngoingCallThreadLocalContextWebrtcCustom *weakSelf = self;
        
        _connection = [[RtcConnection alloc] initWithDiscoveredIceCandidate:^(NSString *sdp, int mLineIndex, NSString *sdpMid) {
            [queue dispatch:^{
                __strong OngoingCallThreadLocalContextWebrtcCustom *strongSelf = weakSelf;
                if (strongSelf == nil) {
                    return;
                }
                [strongSelf sendCandidateWithSdp:sdp mLineIndex:mLineIndex sdpMid:sdpMid];
            }];
        } connectionStateChanged:^(bool isConnected) {
            [queue dispatch:^{
                __strong OngoingCallThreadLocalContextWebrtcCustom *strongSelf = weakSelf;
                if (strongSelf == nil) {
                    return;
                }
                if (strongSelf.stateChanged) {
                    strongSelf.stateChanged(isConnected ? OngoingCallStateConnected : OngoingCallStateInitializing);
                }
            }];
        }];
        
        //RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:@{ @"DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue }];
        
        /*RTCVideoSource *videoSource = [_peerConnectionFactory videoSource];
        
        #if TARGET_OS_SIMULATOR
        _videoCapturer = [[RTCFileVideoCapturer alloc] initWithDelegate:videoSource];
        #else
        _videoCapturer = [[RTCCameraVideoCapturer alloc] initWithDelegate:videoSource];
        #endif
        
        _localVideoTrack = [_peerConnectionFactory videoTrackWithSource:videoSource trackId:@"video0"];
        [_peerConnection addTrack:_localVideoTrack streamIds:@[streamId]];*/
        
        if (isOutgoing) {
            id<OngoingCallThreadLocalContextQueueWebrtcCustom> queue = _queue;
            
            [_connection getOffer:^(NSString *sdp, NSString *type) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtcCustom *strongSelf = weakSelf;
                    if (strongSelf == nil) {
                        return;
                    }
                    
                    [strongSelf->_connection setLocalDescription:sdp type:type completion:^{
                        [queue dispatch:^{
                            __strong OngoingCallThreadLocalContextWebrtcCustom *strongSelf = weakSelf;
                            if (strongSelf == nil) {
                                return;
                            }
                            [strongSelf tryAdvertising:sdp type:type];
                        }];
                    }];
                }];
            }];
        }
    }
    return self;
}

- (void)dealloc {
    assert([_queue isCurrent]);
}

- (void)tryAdvertising:(NSString *)sdp type:(NSString *)type {
    if (_receivedRemoteDescription) {
        return;
    }
    
    [self sendSdp:sdp type:type];
    __weak OngoingCallThreadLocalContextWebrtcCustom *weakSelf = self;
    [_queue dispatchAfter:1.0 block:^{
        __strong OngoingCallThreadLocalContextWebrtcCustom *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        [strongSelf tryAdvertising:sdp type:type];
    }];
}

- (bool)needRate {
    return false;
}

- (void)stop:(void (^)(NSString *, int64_t, int64_t, int64_t, int64_t))completion {
    [_connection close];
    if (completion) {
        completion(@"", 0, 0, 0, 0);
    }
}

- (NSString *)debugInfo {
    NSString *version = [self version];
    return [NSString stringWithFormat:@"WebRTC, Version: %@", version];
}

- (NSString *)version {
    return [OngoingCallThreadLocalContextWebrtcCustom version];
}

- (NSData * _Nonnull)getDerivedState {
    return [NSData data];
}

- (void)sendSdp:(NSString *)sdp type:(NSString *)type {
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    json[@"messageType"] = @"sessionDescription";
    json[@"sdp"] = sdp;
    json[@"type"] = type;
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    if (data != nil) {
        _sendSignalingData(data);
    }
}

- (void)sendCandidateWithSdp:(NSString *)sdp mLineIndex:(int)mLineIndex sdpMid:(NSString *)sdpMid {
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    json[@"messageType"] = @"iceCandidate";
    json[@"sdp"] = sdp;
    json[@"mLineIndex"] = @(mLineIndex);
    if (sdpMid != nil) {
        json[@"sdpMid"] = sdpMid;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    if (data != nil) {
        _sendSignalingData(data);
    }
}

- (void)receiveSignalingData:(NSData *)data {
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSString *messageType = json[@"messageType"];
    if (![messageType isKindOfClass:[NSString class]]) {
        return;
    }
    
    if ([messageType isEqualToString:@"sessionDescription"]) {
        NSString *sdp = json[@"sdp"];
        if (![sdp isKindOfClass:[NSString class]]) {
            return;
        }
        
        NSString *typeString = json[@"type"];
        if (![typeString isKindOfClass:[NSString class]]) {
            return;
        }
        
        if (_receivedRemoteDescription) {
            return;
        }
        _receivedRemoteDescription = true;
        
        [_connection setRemoteDescription:sdp type:typeString completion:^{
        }];
        
        if (!_isOutgoing) {
            __weak OngoingCallThreadLocalContextWebrtcCustom *weakSelf = self;
            id<OngoingCallThreadLocalContextQueueWebrtcCustom> queue = _queue;
            [_connection getAnswer:^(NSString *sdp, NSString *type) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtcCustom *strongSelf = weakSelf;
                    if (strongSelf == nil) {
                        return;
                    }
                    [strongSelf->_connection setLocalDescription:sdp type:type completion:^{
                        [queue dispatch:^{
                            __strong OngoingCallThreadLocalContextWebrtcCustom *strongSelf = weakSelf;
                            if (strongSelf == nil) {
                                return;
                            }
                            [strongSelf sendSdp:sdp type:type];
                        }];
                    }];
                }];
            }];
        }
    } else if ([messageType isEqualToString:@"iceCandidate"]) {
        NSString *sdp = json[@"sdp"];
        if (![sdp isKindOfClass:[NSString class]]) {
            return;
        }
        
        NSNumber *mLineIndex = json[@"mLineIndex"];
        if (![mLineIndex isKindOfClass:[NSNumber class]]) {
            return;
        }
        
        NSString *sdpMidString = json[@"sdpMid"];
        NSString *sdpMid = nil;
        if ([sdpMidString isKindOfClass:[NSString class]]) {
            sdpMid = sdpMidString;
        }
        
        [_connection addIceCandidateWithSdp:sdp sdpMLineIndex:[mLineIndex intValue] sdpMid:sdpMid];
    }
}

- (void)setIsMuted:(bool)isMuted {
    [_connection setIsMuted:isMuted];
}

- (void)setNetworkType:(OngoingCallNetworkTypeWebrtcCustom)networkType {
}

- (void)getRemoteCameraView:(void (^_Nonnull)(UIView * _Nullable))completion {
    [_connection getRemoteCameraView:completion];
}

@end
