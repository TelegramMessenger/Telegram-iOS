#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTDatacenterAuthAction.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>
#import <MtProtoKit/MTDatacenterTransferAuthAction.h>
#import <MtProtoKit/MTBackupAddressSignals.h>
#import <MtProtoKit/MTProto.h>
#import <MtProtoKit/MTExternalActions.h>

@class MTRequest;
@class MTRpcError;
@class MTQueue;

// Module-private interfaces shared by MtProtoKit's sources and its tests.
//
// The actions that produce an auth key (MTDatacenterAuthAction) or transfer an
// auth token (MTDatacenterTransferAuthAction) are the only parts of "a
// connection waits for its key or token" that need the network, so tests
// replace them through the factories of MTExternalActions.h and keep
// everything that decides whether a waiting connection recovers.

@interface MTContext ()

- (MTDatacenterAuthAction * _Nonnull)makeAuthActionWithSelector:(MTDatacenterAuthInfoSelector)selector isCdn:(bool)isCdn skipBind:(bool)skipBind completion:(void (^ _Nonnull)(MTDatacenterAuthAction * _Nonnull, bool))completion;

// How long checkIfLoggedOut waits for its probe before giving up without a
// verdict (120 s). A probe that never ends would otherwise keep the context
// alive through its connection.
@property (nonatomic) NSTimeInterval loggedOutCheckTimeout;

@end

@interface MTDatacenterTransferAuthAction ()

// Gives a transfer request the same error policy as the app's own requests:
// a 500 is retried after a delay instead of failing the transfer.
+ (void)applyRetryPolicyToRequest:(MTRequest * _Nonnull)request;

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
