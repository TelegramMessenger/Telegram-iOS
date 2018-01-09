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

@interface OngoingCallThreadLocalContext : NSObject

+ (void)setupLoggingFunction:(void (*)(NSString *))loggingFunction;

@property (nonatomic, copy) void (^stateChanged)(OngoingCallState);

- (instancetype _Nonnull)init;
- (void)startWithKey:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing primaryConnection:(OngoingCallConnectionDescription * _Nonnull)primaryConnection alternativeConnections:(NSArray<OngoingCallConnectionDescription *> * _Nonnull)alternativeConnections;
- (void)stop;

- (void)setIsMuted:(bool)isMuted;

@end

#endif
