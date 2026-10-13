#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTDatacenterAuthAction.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>
#import <MtProtoKit/MTDatacenterTransferAuthAction.h>
#import <MtProtoKit/MTBackupAddressSignals.h>
#import <MtProtoKit/MTProto.h>

@class MTRequest;
@class MTRpcError;
@class MTQueue;

// Module-private interfaces shared by MtProtoKit's sources and its tests.
//
// The actions that produce an auth key (MTDatacenterAuthAction) or transfer an
// auth token (MTDatacenterTransferAuthAction) are the only parts of "a
// connection waits for its key or token" that need the network, so tests
// replace them through the factories below and keep everything that decides
// whether a waiting connection recovers.

@interface MTContext ()

// Builds the action that transfers a datacenter's auth token. nil (the
// default) means a real MTDatacenterTransferAuthAction.
@property (nonatomic, copy) MTDatacenterTransferAuthAction * _Nonnull (^ _Nullable transferAuthActionFactory)(void);

// Builds the action that creates an auth key. nil (the default) means a real
// MTDatacenterAuthAction.
@property (nonatomic, copy) MTDatacenterAuthAction * _Nonnull (^ _Nullable authActionFactory)(MTDatacenterAuthInfoSelector selector, bool isCdn, bool skipBind, void (^ _Nonnull completion)(MTDatacenterAuthAction * _Nonnull, bool));

- (MTDatacenterAuthAction * _Nonnull)makeAuthActionWithSelector:(MTDatacenterAuthInfoSelector)selector isCdn:(bool)isCdn skipBind:(bool)skipBind completion:(void (^ _Nonnull)(MTDatacenterAuthAction * _Nonnull, bool))completion;

@end

@interface MTDatacenterTransferAuthAction ()

// How a transfer reports its outcome. A test double overrides the execute
// method and calls these, so the reporting path is the production one.
- (void)complete;
- (void)fail;

// Gives a transfer request the same error policy as the app's own requests:
// a 500 is retried after a delay instead of failing the transfer.
+ (void)applyRetryPolicyToRequest:(MTRequest * _Nonnull)request;

@end

@interface MTDatacenterAuthAction ()

// The error auth.bindTempAuthKey answered with, when a bind failed.
@property (nonatomic, strong) MTRpcError * _Nullable bindError;

// Creates a new key even when the context already holds one for the selector,
// so a temporary key can be replaced before it expires.
@property (nonatomic) bool replacesExistingKey;

- (void)complete;
- (void)fail;

// True only for the answer that means the server no longer knows the
// permanent key (ENCRYPTED_MESSAGE_INVALID). Any other bind failure says
// nothing about whether the key still exists.
+ (bool)bindErrorMeansPermanentKeyIsUnknown:(MTRpcError * _Nullable)bindError;

@end

@interface MTBackupAddressSignals ()

// Applies a getConfig address list to the context, touching only the
// datacenters whose address set actually changed. Returns whether any did.
+ (bool)applyAddressList:(NSDictionary<NSNumber *, NSArray *> * _Nonnull)addressList toContext:(MTContext * _Nonnull)context;

@end

@interface MTProto ()

+ (MTQueue * _Nonnull)managerQueue;

@end

// The dc field of p_q_inner_data_dc / p_q_inner_data_temp_dc: the datacenter id,
// plus 10000 on the test servers, negative on a media-only (non-CDN) address.
int32_t MTDatacenterAuthInnerDataDatacenterId(NSInteger datacenterId, bool isTestingEnvironment, bool media, bool cdn);

// Serialized p_q_inner_data_dc, or p_q_inner_data_temp_dc with expires_in when temporary.
NSData * _Nonnull MTDatacenterAuthInnerData(NSData * _Nonnull pq, NSData * _Nonnull p, NSData * _Nonnull q, NSData * _Nonnull nonce, NSData * _Nonnull serverNonce, NSData * _Nonnull newNonce, int32_t datacenterId, bool temporary, int32_t expiresIn);
