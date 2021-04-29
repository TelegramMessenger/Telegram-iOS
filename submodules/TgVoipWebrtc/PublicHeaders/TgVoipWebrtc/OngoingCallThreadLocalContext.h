#ifndef OngoingCallContext_h
#define OngoingCallContext_h

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#define UIView NSView
#endif

@interface OngoingCallConnectionDescriptionWebrtc : NSObject

@property (nonatomic, readonly) int64_t connectionId;
@property (nonatomic, readonly) bool hasStun;
@property (nonatomic, readonly) bool hasTurn;
@property (nonatomic, strong, readonly) NSString * _Nonnull ip;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, strong, readonly) NSString * _Nonnull username;
@property (nonatomic, strong, readonly) NSString * _Nonnull password;

- (instancetype _Nonnull)initWithConnectionId:(int64_t)connectionId hasStun:(bool)hasStun hasTurn:(bool)hasTurn ip:(NSString * _Nonnull)ip port:(int32_t)port username:(NSString * _Nonnull)username password:(NSString * _Nonnull)password;

@end

typedef NS_ENUM(int32_t, OngoingCallStateWebrtc) {
    OngoingCallStateInitializing,
    OngoingCallStateConnected,
    OngoingCallStateFailed,
    OngoingCallStateReconnecting
};

typedef NS_ENUM(int32_t, OngoingCallVideoStateWebrtc) {
    OngoingCallVideoStateInactive,
    OngoingCallVideoStateActive,
    OngoingCallVideoStatePaused
};

typedef NS_ENUM(int32_t, OngoingCallRemoteVideoStateWebrtc) {
    OngoingCallRemoteVideoStateInactive,
    OngoingCallRemoteVideoStateActive,
    OngoingCallRemoteVideoStatePaused
};

typedef NS_ENUM(int32_t, OngoingCallRemoteAudioStateWebrtc) {
    OngoingCallRemoteAudioStateMuted,
    OngoingCallRemoteAudioStateActive,
};

typedef NS_ENUM(int32_t, OngoingCallRemoteBatteryLevelWebrtc) {
    OngoingCallRemoteBatteryLevelNormal,
    OngoingCallRemoteBatteryLevelLow
};

typedef NS_ENUM(int32_t, OngoingCallVideoOrientationWebrtc) {
    OngoingCallVideoOrientation0,
    OngoingCallVideoOrientation90,
    OngoingCallVideoOrientation180,
    OngoingCallVideoOrientation270
};

typedef NS_ENUM(int32_t, OngoingCallNetworkTypeWebrtc) {
    OngoingCallNetworkTypeWifi,
    OngoingCallNetworkTypeCellularGprs,
    OngoingCallNetworkTypeCellularEdge,
    OngoingCallNetworkTypeCellular3g,
    OngoingCallNetworkTypeCellularLte
};

typedef NS_ENUM(int32_t, OngoingCallDataSavingWebrtc) {
    OngoingCallDataSavingNever,
    OngoingCallDataSavingCellular,
    OngoingCallDataSavingAlways
};

@protocol OngoingCallThreadLocalContextQueueWebrtc <NSObject>

- (void)dispatch:(void (^ _Nonnull)())f;
- (bool)isCurrent;

@end

@interface VoipProxyServerWebrtc : NSObject

@property (nonatomic, strong, readonly) NSString * _Nonnull host;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, strong, readonly) NSString * _Nullable username;
@property (nonatomic, strong, readonly) NSString * _Nullable password;

- (instancetype _Nonnull)initWithHost:(NSString * _Nonnull)host port:(int32_t)port username:(NSString * _Nullable)username password:(NSString * _Nullable)password;

@end

@protocol OngoingCallThreadLocalContextWebrtcVideoView <NSObject>

@property (nonatomic, readonly) OngoingCallVideoOrientationWebrtc orientation;
@property (nonatomic, readonly) CGFloat aspect;

- (void)setOnFirstFrameReceived:(void (^ _Nullable)(float))onFirstFrameReceived;
- (void)setOnOrientationUpdated:(void (^ _Nullable)(OngoingCallVideoOrientationWebrtc, CGFloat))onOrientationUpdated;
- (void)setOnIsMirroredUpdated:(void (^ _Nullable)(bool))onIsMirroredUpdated;
#if defined(WEBRTC_MAC) && !defined(WEBRTC_IOS)
- (void)setVideoContentMode:(CALayerContentsGravity _Nonnull )mode;
- (void)setForceMirrored:(bool)forceMirrored;
#endif
@end

@interface OngoingCallThreadLocalContextVideoCapturer : NSObject

- (instancetype _Nonnull)initWithDeviceId:(NSString * _Nonnull)deviceId keepLandscape:(bool)keepLandscape;

- (void)switchVideoInput:(NSString * _Nonnull)deviceId;
- (void)setIsVideoEnabled:(bool)isVideoEnabled;

- (void)makeOutgoingVideoView:(void (^_Nonnull)(UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable))completion;

@end

@interface OngoingCallThreadLocalContextWebrtc : NSObject

+ (void)setupLoggingFunction:(void (* _Nullable)(NSString * _Nullable))loggingFunction;
+ (void)applyServerConfig:(NSString * _Nullable)data;
+ (int32_t)maxLayer;
+ (NSArray<NSString *> * _Nonnull)versionsWithIncludeReference:(bool)includeReference;

@property (nonatomic, copy) void (^ _Nullable stateChanged)(OngoingCallStateWebrtc, OngoingCallVideoStateWebrtc, OngoingCallRemoteVideoStateWebrtc, OngoingCallRemoteAudioStateWebrtc, OngoingCallRemoteBatteryLevelWebrtc, float);
@property (nonatomic, copy) void (^ _Nullable signalBarsChanged)(int32_t);
@property (nonatomic, copy) void (^ _Nullable audioLevelUpdated)(float);

- (instancetype _Nonnull)initWithVersion:(NSString * _Nonnull)version queue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue proxy:(VoipProxyServerWebrtc * _Nullable)proxy networkType:(OngoingCallNetworkTypeWebrtc)networkType dataSaving:(OngoingCallDataSavingWebrtc)dataSaving derivedState:(NSData * _Nonnull)derivedState key:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing connections:(NSArray<OngoingCallConnectionDescriptionWebrtc *> * _Nonnull)connections maxLayer:(int32_t)maxLayer allowP2P:(BOOL)allowP2P allowTCP:(BOOL)allowTCP enableStunMarking:(BOOL)enableStunMarking logPath:(NSString * _Nonnull)logPath statsLogPath:(NSString * _Nonnull)statsLogPath sendSignalingData:(void (^ _Nonnull)(NSData * _Nonnull))sendSignalingData videoCapturer:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer preferredVideoCodec:(NSString * _Nullable)preferredVideoCodec audioInputDeviceId: (NSString * _Nonnull)audioInputDeviceId;

- (void)beginTermination;
- (void)stop:(void (^_Nullable)(NSString * _Nullable debugLog, int64_t bytesSentWifi, int64_t bytesReceivedWifi, int64_t bytesSentMobile, int64_t bytesReceivedMobile))completion;

- (bool)needRate;

- (NSString * _Nullable)debugInfo;
- (NSString * _Nullable)version;
- (NSData * _Nonnull)getDerivedState;

- (void)setIsMuted:(bool)isMuted;
- (void)setIsLowBatteryLevel:(bool)isLowBatteryLevel;
- (void)setNetworkType:(OngoingCallNetworkTypeWebrtc)networkType;
- (void)makeIncomingVideoView:(void (^_Nonnull)(UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable))completion;
- (void)requestVideo:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer;
- (void)setRequestedVideoAspect:(float)aspect;
- (void)disableVideo;
- (void)addSignalingData:(NSData * _Nonnull)data;
- (void)switchAudioOutput:(NSString * _Nonnull)deviceId;
- (void)switchAudioInput:(NSString * _Nonnull)deviceId;
@end

typedef struct {
    bool isConnected;
    bool isTransitioningFromBroadcastToRtc;
} GroupCallNetworkState;

@interface OngoingGroupCallParticipantDescription : NSObject

@property (nonatomic, readonly) uint32_t audioSsrc;
@property (nonatomic, strong, readonly) NSString * _Nullable jsonParams;

- (instancetype _Nonnull)initWithAudioSsrc:(uint32_t)audioSsrc jsonParams:(NSString * _Nullable)jsonParams;

@end

@protocol OngoingGroupCallBroadcastPartTask <NSObject>

- (void)cancel;

@end

typedef NS_ENUM(int32_t, OngoingCallConnectionMode) {
    OngoingCallConnectionModeNone,
    OngoingCallConnectionModeRtc,
    OngoingCallConnectionModeBroadcast
};

typedef NS_ENUM(int32_t, OngoingGroupCallBroadcastPartStatus) {
    OngoingGroupCallBroadcastPartStatusSuccess,
    OngoingGroupCallBroadcastPartStatusNotReady,
    OngoingGroupCallBroadcastPartStatusResyncNeeded
};

@interface OngoingGroupCallBroadcastPart : NSObject

@property (nonatomic, readonly) int64_t timestampMilliseconds;
@property (nonatomic, readonly) double responseTimestamp;
@property (nonatomic, readonly) OngoingGroupCallBroadcastPartStatus status;
@property (nonatomic, strong, readonly) NSData * _Nonnull oggData;

- (instancetype _Nonnull)initWithTimestampMilliseconds:(int64_t)timestampMilliseconds responseTimestamp:(double)responseTimestamp status:(OngoingGroupCallBroadcastPartStatus)status oggData:(NSData * _Nonnull)oggData;

@end

@interface GroupCallThreadLocalContext : NSObject

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue networkStateUpdated:(void (^ _Nonnull)(GroupCallNetworkState))networkStateUpdated audioLevelsUpdated:(void (^ _Nonnull)(NSArray<NSNumber *> * _Nonnull))audioLevelsUpdated inputDeviceId:(NSString * _Nonnull)inputDeviceId outputDeviceId:(NSString * _Nonnull)outputDeviceId videoCapturer:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer incomingVideoSourcesUpdated:(void (^ _Nonnull)(NSArray<NSNumber *> * _Nonnull))incomingVideoSourcesUpdated participantDescriptionsRequired:(void (^ _Nonnull)(NSArray<NSNumber *> * _Nonnull))participantDescriptionsRequired requestBroadcastPart:(id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull)(int64_t, int64_t, void (^ _Nonnull)(OngoingGroupCallBroadcastPart * _Nullable)))requestBroadcastPart outgoingAudioBitrateKbit:(int32_t)outgoingAudioBitrateKbit enableVideo:(bool)enableVideo enableNoiseSuppression:(bool)enableNoiseSuppression;

- (void)stop;

- (void)setConnectionMode:(OngoingCallConnectionMode)connectionMode keepBroadcastConnectedIfWasEnabled:(bool)keepBroadcastConnectedIfWasEnabled;

- (void)emitJoinPayload:(void (^ _Nonnull)(NSString * _Nonnull, uint32_t))completion;
- (void)setJoinResponsePayload:(NSString * _Nonnull)payload participants:(NSArray<OngoingGroupCallParticipantDescription *> * _Nonnull)participants;
- (void)removeSsrcs:(NSArray<NSNumber *> * _Nonnull)ssrcs;
- (void)addParticipants:(NSArray<OngoingGroupCallParticipantDescription *> * _Nonnull)participants;
- (void)setIsMuted:(bool)isMuted;
- (void)setIsNoiseSuppressionEnabled:(bool)isNoiseSuppressionEnabled;
- (void)requestVideo:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer completion:(void (^ _Nonnull)(NSString * _Nonnull, uint32_t))completion;
- (void)disableVideo:(void (^ _Nonnull)(NSString * _Nonnull, uint32_t))completion;

- (void)setVolumeForSsrc:(uint32_t)ssrc volume:(double)volume;
- (void)setFullSizeVideoSsrc:(uint32_t)ssrc;

- (void)switchAudioOutput:(NSString * _Nonnull)deviceId;
- (void)switchAudioInput:(NSString * _Nonnull)deviceId;
- (void)makeIncomingVideoViewWithSsrc:(uint32_t)ssrc completion:(void (^_Nonnull)(UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable))completion;

@end

#endif
