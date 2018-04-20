#ifndef OngoingCallContext_h
#define OngoingCallContext_h

#import <Foundation/Foundation.h>

@interface OngoingCallConnectionDescription : NSObject

@property (nonatomic, readonly) int64_t connectionId;
@property (nonatomic, strong, readonly) NSString * _Nonnull ip;
@property (nonatomic, strong, readonly) NSString * _Nonnull ipv6;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, strong, readonly) NSData * _Nonnull peerTag;

- (instancetype _Nonnull)initWithConnectionId:(int64_t)connectionId ip:(NSString * _Nonnull)ip ipv6:(NSString * _Nonnull)ipv6 port:(int32_t)port peerTag:(NSData * _Nonnull)peerTag;

@end

typedef NS_ENUM(int32_t, OngoingCallState) {
    OngoingCallStateInitializing,
    OngoingCallStateConnected,
    OngoingCallStateFailed
};

@protocol OngoingCallThreadLocalContextQueue <NSObject>

- (void)dispatch:(void (^ _Nonnull)())f;
- (bool)isCurrent;

@end

@interface VoipProxyServer : NSObject

@property (nonatomic, strong, readonly) NSString * _Nonnull host;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, strong, readonly) NSString * _Nullable username;
@property (nonatomic, strong, readonly) NSString * _Nullable password;

- (instancetype _Nonnull)initWithHost:(NSString * _Nonnull)host port:(int32_t)port username:(NSString * _Nullable)username password:(NSString * _Nullable)password;

@end

@interface OngoingCallThreadLocalContext : NSObject

+ (void)setupLoggingFunction:(void (* _Nullable)(NSString * _Nullable))loggingFunction;

@property (nonatomic, copy) void (^ _Nullable stateChanged)(OngoingCallState);

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueue> _Nonnull)queue proxy:(VoipProxyServer * _Nullable)proxy;
- (void)startWithKey:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing primaryConnection:(OngoingCallConnectionDescription * _Nonnull)primaryConnection alternativeConnections:(NSArray<OngoingCallConnectionDescription *> * _Nonnull)alternativeConnections maxLayer:(int32_t)maxLayer;
- (void)stop;

- (void)setIsMuted:(bool)isMuted;

@end

#endif
