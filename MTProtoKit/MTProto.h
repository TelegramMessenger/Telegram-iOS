/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@protocol MTMessageService;
@class MTQueue;
@class MTContext;
@class MTNetworkUsageCalculationInfo;
@class MTApiEnvironment;
@class MTDatacenterAuthKey;

@class MTProto;

@interface MTProtoConnectionState : NSObject

@property (nonatomic, readonly) bool isConnected;
@property (nonatomic, readonly) bool isUsingProxy;

@end

@protocol MTProtoDelegate <NSObject>

@optional

- (void)mtProtoNetworkAvailabilityChanged:(MTProto *)mtProto isNetworkAvailable:(bool)isNetworkAvailable;
- (void)mtProtoConnectionStateChanged:(MTProto *)mtProto state:(MTProtoConnectionState *)state;
- (void)mtProtoConnectionContextUpdateStateChanged:(MTProto *)mtProto isUpdatingConnectionContext:(bool)isUpdatingConnectionContext;
- (void)mtProtoServiceTasksStateChanged:(MTProto *)mtProto isPerformingServiceTasks:(bool)isPerformingServiceTasks;

@end

@interface MTProto : NSObject

@property (nonatomic, weak) id<MTProtoDelegate> delegate;

@property (nonatomic, strong, readonly) MTContext *context;
@property (nonatomic, strong, readonly) MTApiEnvironment *apiEnvironment;
@property (nonatomic) NSInteger datacenterId;

@property (nonatomic) bool shouldStayConnected;
@property (nonatomic) bool useUnauthorizedMode;
@property (nonatomic) bool useTempAuthKeys;
@property (nonatomic) bool media;
@property (nonatomic) bool cdn;
@property (nonatomic) id requiredAuthToken;
@property (nonatomic) NSInteger authTokenMasterDatacenterId;

- (instancetype)initWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId usageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo;

- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo;

- (void)pause;
- (void)resume;
- (void)stop;

- (void)addMessageService:(id<MTMessageService>)messageService;
- (void)removeMessageService:(id<MTMessageService>)messageService;
- (MTQueue *)messageServiceQueue;
- (void)requestTransportTransaction;
- (void)requestSecureTransportReset;
- (void)resetSessionInfo;
- (void)requestTimeResync;

- (void)_messageResendRequestFailed:(int64_t)messageId;

- (void)bindToPersistentKey:(MTDatacenterAuthKey *)persistentKey completion:(void (^)())completion;

@end
