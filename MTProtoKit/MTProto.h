/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

@protocol MTMessageService;
@class MTQueue;
@class MTContext;

@class MTProto;

@protocol MTProtoDelegate <NSObject>

@optional

- (void)mtProtoNetworkAvailabilityChanged:(MTProto *)mtProto isNetworkAvailable:(bool)isNetworkAvailable;
- (void)mtProtoConnectionStateChanged:(MTProto *)mtProto isConnected:(bool)isConnected;
- (void)mtProtoConnectionContextUpdateStateChanged:(MTProto *)mtProto isUpdatingConnectionContext:(bool)isUpdatingConnectionContext;
- (void)mtProtoServiceTasksStateChanged:(MTProto *)mtProto isPerformingServiceTasks:(bool)isPerformingServiceTasks;

@end

@interface MTProto : NSObject

@property (nonatomic, weak) id<MTProtoDelegate> delegate;

@property (nonatomic, strong) MTContext *context;
@property (nonatomic) NSInteger datacenterId;

@property (nonatomic) bool shouldStayConnected;
@property (nonatomic) bool useUnauthorizedMode;
@property (nonatomic) id requiredAuthToken;
@property (nonatomic) NSInteger authTokenMasterDatacenterId;

- (instancetype)initWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId;

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

@end
