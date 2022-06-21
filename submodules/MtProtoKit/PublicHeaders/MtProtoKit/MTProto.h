

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
@property (nonatomic, readonly) NSString *proxyAddress;
@property (nonatomic, readonly) bool proxyHasConnectionIssues;

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
@property (nonatomic, strong) MTDatacenterAuthKey *useExplicitAuthKey;

@property (nonatomic, copy) void (^tempAuthKeyBindingResultUpdated)(bool);

@property (nonatomic) bool shouldStayConnected;
@property (nonatomic) bool useUnauthorizedMode;
@property (nonatomic) bool useTempAuthKeys;
@property (nonatomic) bool media;
@property (nonatomic) bool enforceMedia;
@property (nonatomic) bool cdn;
@property (nonatomic) bool allowUnboundEphemeralKeys;
@property (nonatomic) bool checkForProxyConnectionIssues;
@property (nonatomic) bool canResetAuthData;
@property (nonatomic) id requiredAuthToken;
@property (nonatomic) NSInteger authTokenMasterDatacenterId;

@property (nonatomic, strong) NSString *(^getLogPrefix)();

- (instancetype)initWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId usageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo requiredAuthToken:(id)requiredAuthToken authTokenMasterDatacenterId:(NSInteger)authTokenMasterDatacenterId;

- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo;

- (void)pause;
- (void)resume;
- (void)stop;
- (void)finalizeSession;

- (void)addMessageService:(id<MTMessageService>)messageService;
- (void)removeMessageService:(id<MTMessageService>)messageService;
- (MTQueue *)messageServiceQueue;
- (void)requestTransportTransaction;
- (void)requestSecureTransportReset;
- (void)resetSessionInfo;
- (void)requestTimeResync;

- (void)_messageResendRequestFailed:(int64_t)messageId;

+ (NSData *)_manuallyEncryptedMessage:(NSData *)preparedData messageId:(int64_t)messageId authKey:(MTDatacenterAuthKey *)authKey;

@end
