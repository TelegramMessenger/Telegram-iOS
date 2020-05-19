#ifndef OngoingCallContext_h
#define OngoingCallContext_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface OngoingCallConnectionDescriptionWebrtcCustom : NSObject

@property (nonatomic, readonly) int64_t connectionId;
@property (nonatomic, strong, readonly) NSString * _Nonnull ip;
@property (nonatomic, strong, readonly) NSString * _Nonnull ipv6;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, strong, readonly) NSData * _Nonnull peerTag;

- (instancetype _Nonnull)initWithConnectionId:(int64_t)connectionId ip:(NSString * _Nonnull)ip ipv6:(NSString * _Nonnull)ipv6 port:(int32_t)port peerTag:(NSData * _Nonnull)peerTag;

@end

typedef NS_ENUM(int32_t, OngoingCallStateWebrtcCustom) {
    OngoingCallStateInitializing,
    OngoingCallStateConnected,
    OngoingCallStateFailed,
    OngoingCallStateReconnecting
};

typedef NS_ENUM(int32_t, OngoingCallNetworkTypeWebrtcCustom) {
    OngoingCallNetworkTypeWifi,
    OngoingCallNetworkTypeCellularGprs,
    OngoingCallNetworkTypeCellularEdge,
    OngoingCallNetworkTypeCellular3g,
    OngoingCallNetworkTypeCellularLte
};

typedef NS_ENUM(int32_t, OngoingCallDataSavingWebrtcCustom) {
    OngoingCallDataSavingNever,
    OngoingCallDataSavingCellular,
    OngoingCallDataSavingAlways
};

@protocol OngoingCallThreadLocalContextQueueWebrtcCustom <NSObject>

- (void)dispatch:(void (^ _Nonnull)())f;
- (void)dispatchAfter:(double)seconds block:(void (^ _Nonnull)())f;
- (bool)isCurrent;

@end

@interface VoipProxyServerWebrtcCustom : NSObject

@property (nonatomic, strong, readonly) NSString * _Nonnull host;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, strong, readonly) NSString * _Nullable username;
@property (nonatomic, strong, readonly) NSString * _Nullable password;

- (instancetype _Nonnull)initWithHost:(NSString * _Nonnull)host port:(int32_t)port username:(NSString * _Nullable)username password:(NSString * _Nullable)password;

@end

@interface OngoingCallThreadLocalContextWebrtcCustom : NSObject

+ (void)setupLoggingFunction:(void (* _Nullable)(NSString * _Nullable))loggingFunction;
+ (void)applyServerConfig:(NSString * _Nullable)data;
+ (int32_t)maxLayer;
+ (NSString * _Nonnull)version;

@property (nonatomic, copy) void (^ _Nullable stateChanged)(OngoingCallStateWebrtcCustom);
@property (nonatomic, copy) void (^ _Nullable signalBarsChanged)(int32_t);

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueueWebrtcCustom> _Nonnull)queue proxy:(VoipProxyServerWebrtcCustom * _Nullable)proxy networkType:(OngoingCallNetworkTypeWebrtcCustom)networkType dataSaving:(OngoingCallDataSavingWebrtcCustom)dataSaving derivedState:(NSData * _Nonnull)derivedState key:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing primaryConnection:(OngoingCallConnectionDescriptionWebrtcCustom * _Nonnull)primaryConnection alternativeConnections:(NSArray<OngoingCallConnectionDescriptionWebrtcCustom *> * _Nonnull)alternativeConnections maxLayer:(int32_t)maxLayer allowP2P:(BOOL)allowP2P logPath:(NSString * _Nonnull)logPath sendSignalingData:(void (^)(NSData * _Nonnull))sendSignalingData;
- (void)stop:(void (^_Nullable)(NSString * _Nullable debugLog, int64_t bytesSentWifi, int64_t bytesReceivedWifi, int64_t bytesSentMobile, int64_t bytesReceivedMobile))completion;

- (bool)needRate;
    
- (NSString * _Nullable)debugInfo;
- (NSString * _Nullable)version;
- (NSData * _Nonnull)getDerivedState;


- (void)receiveSignalingData:(NSData * _Nonnull)data;

- (void)setIsMuted:(bool)isMuted;
- (void)setNetworkType:(OngoingCallNetworkTypeWebrtcCustom)networkType;
- (void)getRemoteCameraView:(void (^_Nonnull)(UIView * _Nullable))completion;

@end

#endif
