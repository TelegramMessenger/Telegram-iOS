#import <Foundation/Foundation.h>

#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTDatacenterAuthAction.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>
#import <MtProtoKit/MTDatacenterTransferAuthAction.h>

@class MTRpcError;

// Who makes MTContext's auth keys and transfers its authorizations.
//
// MTContext keeps one action per datacenter and selector (one per datacenter for a
// transfer), retries failed ones with backoff and wakes the connections that wait;
// an action only does the network part. Another network engine installs its own
// actions here, so keys and authorizations come over whatever transport it uses
// while MTContext stays the only coordinator and the only writer of keys and tokens.

@interface MTContext ()

// Builds the action that transfers a datacenter's auth token. nil (the
// default) means a real MTDatacenterTransferAuthAction.
@property (atomic, copy) MTDatacenterTransferAuthAction * _Nonnull (^ _Nullable transferAuthActionFactory)(void);

// Builds the action that creates an auth key. nil (the default) means a real
// MTDatacenterAuthAction.
@property (atomic, copy) MTDatacenterAuthAction * _Nonnull (^ _Nullable authActionFactory)(MTDatacenterAuthInfoSelector selector, bool isCdn, bool skipBind, void (^ _Nonnull completion)(MTDatacenterAuthAction * _Nonnull, bool));

@end

// What a subclass of MTDatacenterAuthAction that makes keys elsewhere needs. It
// overrides execute:datacenterId: and cancel, and reports through these, so the
// key is stored exactly as MtProtoKit's own action stores it.
@interface MTDatacenterAuthAction ()

// The error auth.bindTempAuthKey answered with, when a bind failed.
@property (nonatomic, strong) MTRpcError * _Nullable bindError;

// Creates a new key even when the context already holds one for the selector,
// so a temporary key can be replaced before it expires.
@property (nonatomic) bool replacesExistingKey;

// Set, the action only asks whether the server still knows this permanent key
// (MTContext.checkIfLoggedOut): it always makes a fresh temporary key, binds
// it to this key rather than to whatever the context holds by then, never
// stores it, and reports the bind's outcome (success, or failure with
// bindError).
@property (nonatomic, strong) MTDatacenterAuthKey * _Nullable probedPermanentKey;

// The context and datacenter the action works for; execute:datacenterId:
// sets them. A subclass that does not call it sets them before reporting.
- (void)attachToContext:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId;

// A permanent key a subclass made: stored as MtProtoKit stores its own (the
// first salt valid for 29 minutes from timestamp, a message id), unless the
// context got a permanent key for the datacenter meanwhile, which is kept.
// Then the action completes. Only for the persistent selector.
- (void)completeWithAuthKey:(MTDatacenterAuthKey * _Nonnull)authKey timestamp:(int64_t)timestamp serverSalt:(int64_t)serverSalt;

- (void)complete;
- (void)fail;

// True only for the answer that means the server no longer knows the
// permanent key (ENCRYPTED_MESSAGE_INVALID). Any other bind failure says
// nothing about whether the key still exists.
+ (bool)bindErrorMeansPermanentKeyIsUnknown:(MTRpcError * _Nullable)bindError;

@end

// What a subclass of MTDatacenterTransferAuthAction that transfers an
// authorization elsewhere reports through, so MTContext's backoff and the
// waiting connections see it as MtProtoKit's own transfer.
@interface MTDatacenterTransferAuthAction ()

- (void)complete;
- (void)fail;

@end
