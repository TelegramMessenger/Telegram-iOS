#ifndef OngoingCallContext_h
#define OngoingCallContext_h

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#else
#import <AppKit/AppKit.h>
#define UIView NSView
#endif

@interface OngoingCallConnectionDescriptionWebrtc : NSObject

@property (nonatomic, readonly) uint8_t reflectorId;
@property (nonatomic, readonly) bool hasStun;
@property (nonatomic, readonly) bool hasTurn;
@property (nonatomic, readonly) bool hasTcp;
@property (nonatomic, strong, readonly) NSString * _Nonnull ip;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, strong, readonly) NSString * _Nonnull username;
@property (nonatomic, strong, readonly) NSString * _Nonnull password;

- (instancetype _Nonnull)initWithReflectorId:(uint8_t)reflectorId hasStun:(bool)hasStun hasTurn:(bool)hasTurn hasTcp:(bool)hasTcp ip:(NSString * _Nonnull)ip port:(int32_t)port username:(NSString * _Nonnull)username password:(NSString * _Nonnull)password;

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
- (void)updateIsEnabled:(bool)isEnabled;
#if defined(WEBRTC_MAC) && !defined(WEBRTC_IOS)
- (void)setVideoContentMode:(CALayerContentsGravity _Nonnull )mode;
- (void)setForceMirrored:(bool)forceMirrored;
- (void)setIsPaused:(bool)paused;
- (void)renderToSize:(NSSize)size animated: (bool)animated;
#endif
@end

@interface GroupCallDisposable : NSObject

- (instancetype _Nonnull)initWithBlock:(dispatch_block_t _Nonnull)block;
- (void)dispose;

@end

@protocol CallVideoFrameBuffer

@end

@interface CallVideoFrameNativePixelBuffer : NSObject<CallVideoFrameBuffer>

@property (nonatomic, readonly) CVPixelBufferRef _Nonnull pixelBuffer;

@end

@interface CallVideoFrameNV12Buffer : NSObject<CallVideoFrameBuffer>

@property (nonatomic, readonly) int width;
@property (nonatomic, readonly) int height;

@property (nonatomic, strong, readonly) NSData * _Nonnull y;
@property (nonatomic, readonly) int strideY;

@property (nonatomic, strong, readonly) NSData * _Nonnull uv;
@property (nonatomic, readonly) int strideUV;

@end

@interface CallVideoFrameI420Buffer : NSObject<CallVideoFrameBuffer>

@property (nonatomic, readonly) int width;
@property (nonatomic, readonly) int height;

@property (nonatomic, strong, readonly) NSData * _Nonnull y;
@property (nonatomic, readonly) int strideY;

@property (nonatomic, strong, readonly) NSData * _Nonnull u;
@property (nonatomic, readonly) int strideU;

@property (nonatomic, strong, readonly) NSData * _Nonnull v;
@property (nonatomic, readonly) int strideV;

@end

@interface CallVideoFrameData : NSObject

@property (nonatomic, strong, readonly) id<CallVideoFrameBuffer> _Nonnull buffer;
@property (nonatomic, readonly) int width;
@property (nonatomic, readonly) int height;
@property (nonatomic, readonly) OngoingCallVideoOrientationWebrtc orientation;
@property (nonatomic, readonly) bool mirrorHorizontally;
@property (nonatomic, readonly) bool mirrorVertically;

@end

@interface OngoingCallThreadLocalContextVideoCapturer : NSObject

- (instancetype _Nonnull)initWithDeviceId:(NSString * _Nonnull)deviceId keepLandscape:(bool)keepLandscape;

#if TARGET_OS_IOS
+ (instancetype _Nonnull)capturerWithExternalSampleBufferProvider;
#endif

- (void)switchVideoInput:(NSString * _Nonnull)deviceId;
- (void)setIsVideoEnabled:(bool)isVideoEnabled;

- (void)makeOutgoingVideoView:(bool)requestClone completion:(void (^_Nonnull)(UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable, UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable))completion;

- (void)setOnFatalError:(dispatch_block_t _Nullable)onError;
- (void)setOnPause:(void (^ _Nullable)(bool))onPause;
- (void)setOnIsActiveUpdated:(void (^_Nonnull)(bool))onIsActiveUpdated;

#if TARGET_OS_IOS
- (void)submitPixelBuffer:(CVPixelBufferRef _Nonnull)pixelBuffer rotation:(OngoingCallVideoOrientationWebrtc)rotation;
#endif

- (GroupCallDisposable * _Nonnull)addVideoOutput:(void (^_Nonnull)(CallVideoFrameData * _Nonnull))sink;

@end

@interface OngoingCallThreadLocalContextWebrtc : NSObject

+ (void)logMessage:(NSString * _Nonnull)string;

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
- (void)addExternalAudioData:(NSData * _Nonnull)data;

@end

typedef struct {
    bool isConnected;
    bool isTransitioningFromBroadcastToRtc;
} GroupCallNetworkState;

typedef NS_ENUM(int32_t, OngoingGroupCallMediaChannelType) {
    OngoingGroupCallMediaChannelTypeAudio,
    OngoingGroupCallMediaChannelTypeVideo
};

@interface OngoingGroupCallMediaChannelDescription : NSObject

@property (nonatomic, readonly) OngoingGroupCallMediaChannelType type;
@property (nonatomic, readonly) uint32_t audioSsrc;
@property (nonatomic, strong, readonly) NSString * _Nullable videoDescription;

- (instancetype _Nonnull)initWithType:(OngoingGroupCallMediaChannelType)type
    audioSsrc:(uint32_t)audioSsrc
    videoDescription:(NSString * _Nullable)videoDescription;

@end

@protocol OngoingGroupCallBroadcastPartTask <NSObject>

- (void)cancel;

@end

@protocol OngoingGroupCallMediaChannelDescriptionTask <NSObject>

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

typedef NS_ENUM(int32_t, OngoingGroupCallVideoContentType) {
    OngoingGroupCallVideoContentTypeNone,
    OngoingGroupCallVideoContentTypeGeneric,
    OngoingGroupCallVideoContentTypeScreencast,
};

@interface OngoingGroupCallBroadcastPart : NSObject

@property (nonatomic, readonly) int64_t timestampMilliseconds;
@property (nonatomic, readonly) double responseTimestamp;
@property (nonatomic, readonly) OngoingGroupCallBroadcastPartStatus status;
@property (nonatomic, strong, readonly) NSData * _Nonnull oggData;

- (instancetype _Nonnull)initWithTimestampMilliseconds:(int64_t)timestampMilliseconds responseTimestamp:(double)responseTimestamp status:(OngoingGroupCallBroadcastPartStatus)status oggData:(NSData * _Nonnull)oggData;

@end

typedef NS_ENUM(int32_t, OngoingGroupCallRequestedVideoQuality) {
    OngoingGroupCallRequestedVideoQualityThumbnail,
    OngoingGroupCallRequestedVideoQualityMedium,
    OngoingGroupCallRequestedVideoQualityFull,
};

@interface OngoingGroupCallSsrcGroup : NSObject

@property (nonatomic, strong, readonly) NSString * _Nonnull semantics;
@property (nonatomic, strong, readonly) NSArray<NSNumber *> * _Nonnull ssrcs;

- (instancetype _Nonnull)initWithSemantics:(NSString * _Nonnull)semantics ssrcs:(NSArray<NSNumber *> * _Nonnull)ssrcs;

@end

@interface OngoingGroupCallRequestedVideoChannel : NSObject

@property (nonatomic, readonly) uint32_t audioSsrc;
@property (nonatomic, strong, readonly) NSString * _Nonnull endpointId;
@property (nonatomic, strong, readonly) NSArray<OngoingGroupCallSsrcGroup *> * _Nonnull ssrcGroups;

@property (nonatomic, readonly) OngoingGroupCallRequestedVideoQuality minQuality;
@property (nonatomic, readonly) OngoingGroupCallRequestedVideoQuality maxQuality;

- (instancetype _Nonnull)initWithAudioSsrc:(uint32_t)audioSsrc endpointId:(NSString * _Nonnull)endpointId ssrcGroups:(NSArray<OngoingGroupCallSsrcGroup *> * _Nonnull)ssrcGroups minQuality:(OngoingGroupCallRequestedVideoQuality)minQuality maxQuality:(OngoingGroupCallRequestedVideoQuality)maxQuality;

@end

@interface OngoingGroupCallIncomingVideoStats : NSObject

@property (nonatomic, readonly) int receivingQuality;
@property (nonatomic, readonly) int availableQuality;

- (instancetype _Nonnull)initWithReceivingQuality:(int)receivingQuality availableQuality:(int)availableQuality;

@end

@interface OngoingGroupCallStats : NSObject

@property (nonatomic, strong, readonly) NSDictionary<NSString *, OngoingGroupCallIncomingVideoStats *> * _Nonnull incomingVideoStats;

- (instancetype _Nonnull)initWithIncomingVideoStats:(NSDictionary<NSString *, OngoingGroupCallIncomingVideoStats *> * _Nonnull)incomingVideoStats;

@end

@interface GroupCallThreadLocalContext : NSObject

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue
    networkStateUpdated:(void (^ _Nonnull)(GroupCallNetworkState))networkStateUpdated
    audioLevelsUpdated:(void (^ _Nonnull)(NSArray<NSNumber *> * _Nonnull))audioLevelsUpdated
    inputDeviceId:(NSString * _Nonnull)inputDeviceId
    outputDeviceId:(NSString * _Nonnull)outputDeviceId
    videoCapturer:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer
    requestMediaChannelDescriptions:(id<OngoingGroupCallMediaChannelDescriptionTask> _Nonnull (^ _Nonnull)(NSArray<NSNumber *> * _Nonnull, void (^ _Nonnull)(NSArray<OngoingGroupCallMediaChannelDescription *> * _Nonnull)))requestMediaChannelDescriptions
    requestCurrentTime:(id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull)(void (^ _Nonnull)(int64_t)))requestAudioBroadcastPart
    requestAudioBroadcastPart:(id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull)(int64_t, int64_t, void (^ _Nonnull)(OngoingGroupCallBroadcastPart * _Nullable)))requestAudioBroadcastPart
    requestVideoBroadcastPart:(id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull)(int64_t, int64_t, int32_t, OngoingGroupCallRequestedVideoQuality, void (^ _Nonnull)(OngoingGroupCallBroadcastPart * _Nullable)))requestVideoBroadcastPart
    outgoingAudioBitrateKbit:(int32_t)outgoingAudioBitrateKbit
    videoContentType:(OngoingGroupCallVideoContentType)videoContentType
    enableNoiseSuppression:(bool)enableNoiseSuppression
    disableAudioInput:(bool)disableAudioInput
    preferX264:(bool)preferX264
    logPath:(NSString * _Nonnull)logPath;

- (void)stop;

- (void)setConnectionMode:(OngoingCallConnectionMode)connectionMode keepBroadcastConnectedIfWasEnabled:(bool)keepBroadcastConnectedIfWasEnabled isUnifiedBroadcast:(bool)isUnifiedBroadcast;

- (void)emitJoinPayload:(void (^ _Nonnull)(NSString * _Nonnull, uint32_t))completion;
- (void)setJoinResponsePayload:(NSString * _Nonnull)payload;
- (void)removeSsrcs:(NSArray<NSNumber *> * _Nonnull)ssrcs;
- (void)removeIncomingVideoSource:(uint32_t)ssrc;
- (void)setIsMuted:(bool)isMuted;
- (void)setIsNoiseSuppressionEnabled:(bool)isNoiseSuppressionEnabled;
- (void)requestVideo:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer completion:(void (^ _Nonnull)(NSString * _Nonnull, uint32_t))completion;
- (void)disableVideo:(void (^ _Nonnull)(NSString * _Nonnull, uint32_t))completion;

- (void)setVolumeForSsrc:(uint32_t)ssrc volume:(double)volume;
- (void)setRequestedVideoChannels:(NSArray<OngoingGroupCallRequestedVideoChannel *> * _Nonnull)requestedVideoChannels;

- (void)switchAudioOutput:(NSString * _Nonnull)deviceId;
- (void)switchAudioInput:(NSString * _Nonnull)deviceId;
- (void)makeIncomingVideoViewWithEndpointId:(NSString * _Nonnull)endpointId requestClone:(bool)requestClone completion:(void (^_Nonnull)(UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable, UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable))completion;
- (GroupCallDisposable * _Nonnull)addVideoOutputWithEndpointId:(NSString * _Nonnull)endpointId sink:(void (^_Nonnull)(CallVideoFrameData * _Nonnull))sink;

- (void)addExternalAudioData:(NSData * _Nonnull)data;

- (void)getStats:(void (^ _Nonnull)(OngoingGroupCallStats * _Nonnull))completion;

@end

#endif
