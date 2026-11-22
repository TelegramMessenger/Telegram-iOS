

#import <Foundation/Foundation.h>

@protocol MTMessageService;
@class MTQueue;
@class MTContext;
@class MTNetworkUsageCalculationInfo;
@class MTApiEnvironment;
@class MTDatacenterAuthKey;
@class MTTransport;
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

@property (nonatomic, strong) MTTransport *tempConnectionForReuse;

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
- (void)resetSessionInfo:(bool)ifActive;
- (void)requestTimeResync;

- (void)_messageResendRequestFailed:(int64_t)messageId;

+ (NSData *)_manuallyEncryptedMessage:(NSData *)preparedData messageId:(int64_t)messageId authKey:(MTDatacenterAuthKey *)authKey;

// Builds the MTProto 2.0 plaintext for one outgoing message: the 32-byte header
// (salt, session_id, message_id, seq_no, message_data_length), the body, and
// random padding. The padding is at least 12 bytes, brings the total to a
// multiple of 16, and never exceeds 72 bytes (256 with extendedPadding).
// Exposed for tests.
+ (NSMutableData *)_paddedPlaintextWithSalt:(int64_t)salt sessionId:(int64_t)sessionId messageId:(int64_t)messageId seqNo:(int32_t)seqNo body:(NSData *)body extendedPadding:(bool)extendedPadding;

// Encrypts a padded plaintext into the final transport frame
// (auth_key_id ‖ msg_key ‖ AES-IGE(plaintext)) with a single output allocation.
// quickAckId, when non-NULL, receives the low 31 bits of msg_key_large[0..4].
// Returns nil when the auth key is shorter than 120 bytes, the plaintext is
// empty or not a multiple of 16, or no message key can be derived.
// Exposed for tests.
+ (NSData *)_encryptedTransportDataForPaddedPlaintext:(NSData *)plaintext authKey:(MTDatacenterAuthKey *)authKey quickAckId:(int32_t *)quickAckId;

// Verifies and decrypts a server → client MTProto 2.0 frame
// (auth_key_id ‖ msg_key ‖ AES-IGE(plaintext)) with a single output allocation.
// Returns the padded plaintext (32-byte header, body, padding), or nil when the
// key id or msg_key does not match, message_data_length does not fit, or the
// padding after the body is not 12..1024 bytes. Trailing bytes beyond the last
// 16-byte block are ignored. Exposed for tests.
+ (NSData *)_decryptedPayloadForIncomingTransportData:(NSData *)transportData authKey:(MTDatacenterAuthKey *)authKey;

// Splits a decrypted payload into its header fields and the body that follows
// them. With `unauthorized` the handshake layout is expected
// (auth_key_id = 0 ‖ message_id ‖ message_data_length); otherwise
// salt ‖ session_id ‖ message_id ‖ seq_no ‖ message_data_length. Returns false
// when the header is truncated or, in unauthorized mode, when auth_key_id is
// not 0 or the declared length is below 4. Every out-parameter must be
// non-NULL. Exposed for tests.
+ (bool)_readIncomingPayload:(NSData *)data unauthorized:(bool)unauthorized salt:(int64_t *)salt sessionId:(int64_t *)sessionId messageId:(int64_t *)messageId seqNo:(int32_t *)seqNo topMessageSize:(int32_t *)topMessageSize body:(NSData **)body;

- (void)simulateDisconnection;

- (MTTransport *)takeConnectionForReusing;

@end
