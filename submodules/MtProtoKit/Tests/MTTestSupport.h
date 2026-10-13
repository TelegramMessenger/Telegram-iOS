#import <Foundation/Foundation.h>

#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTProto.h>
#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTDatacenterAuthAction.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>
#import <MtProtoKit/MTDatacenterTransferAuthAction.h>
#import <MtProtoKit/MTRpcError.h>
#import <MtProtoKit/MTTransportScheme.h>

#import "MTInternalInterfaces.h"

// Shared fixtures for the tests that drive MTContext and MTProto without a
// network: a context whose key and token actions are test doubles, and
// observers for what a connection can and cannot do.

bool MTTestWaitUntil(NSTimeInterval timeout, bool (^condition)(void));

// A context with no network-backed collaborators. Nothing listens on the
// addresses it is given, so a connection that gets a transport keeps
// connecting and never exchanges a message.
MTContext *MTTestMakeContext(bool useTempAuthKeys);
MTContext *MTTestMakeContextWithEncryptionProvider(bool useTempAuthKeys, id<EncryptionProvider> encryptionProvider);

MTDatacenterAuthInfo *MTTestMakeAuthInfo(void);
MTDatacenterAddress *MTTestMakeAddress(bool preferForMedia);
void MTTestSetAddress(MTContext *context, NSInteger datacenterId, bool preferForMedia);

// Private MTProto surface the tests drive.
@interface MTProto (MTTestAccess)

+ (MTQueue *)managerQueue;
// What the incoming-message path calls on a -404 ("auth key not found").
- (void)handleMissingKey:(MTTransportScheme *)scheme;
// False while the connection waits for a scheme, a key or a token.
- (bool)canAskForServiceTransactions;

@end

// Runs on MTProto's manager queue and waits, as the production callers do.
void MTTestOnManagerQueue(dispatch_block_t block);
// Whether the connection is waiting for a scheme, a key or a token.
bool MTTestIsWaiting(MTProto *proto);

// Stands in for the network half of a token transfer.
@interface MTTestTransferAuthAction : MTDatacenterTransferAuthAction

@property (nonatomic, readonly) NSInteger destinationDatacenterId;

- (instancetype)initWithOnExecute:(void (^)(MTTestTransferAuthAction *))onExecute;

// importAuthorization succeeded: the token is now valid on the destination.
- (void)succeed;
// The transfer ended with an error its requests do not retry (for example
// importAuthorization answering AUTH_BYTES_INVALID).
- (void)failWithError;

@end

// Stands in for the network half of auth key creation (DH, then bind).
@interface MTTestAuthAction : MTDatacenterAuthAction

@property (nonatomic, readonly) MTDatacenterAuthInfoSelector selector;
@property (nonatomic, readonly) NSInteger datacenterId;

- (instancetype)initWithSelector:(MTDatacenterAuthInfoSelector)selector completion:(void (^)(MTDatacenterAuthAction *, bool))completion onExecute:(void (^)(MTTestAuthAction *))onExecute;

// The key was created (and bound): it is now in the context.
- (void)succeed;
// auth.bindTempAuthKey answered with this error.
- (void)failWithBindError:(MTRpcError *)error;

@end

// Records every key and token action a context starts.
@interface MTTestActionRecorder : NSObject

- (instancetype)initWithContext:(MTContext *)context;

- (NSUInteger)transferCount;
- (MTTestTransferAuthAction *)transferAtIndex:(NSUInteger)index;
- (bool)waitForTransferCount:(NSUInteger)count timeout:(NSTimeInterval)timeout;

- (NSUInteger)authActionCount;
- (MTTestAuthAction *)authActionAtIndex:(NSUInteger)index;
- (bool)waitForAuthActionCount:(NSUInteger)count timeout:(NSTimeInterval)timeout;

@end

// Records whether an MTProto currently has a transport: MTProto reports a
// connection state only through a transport, and a nil state when it has none.
@interface MTTestProtoObserver : NSObject <MTProtoDelegate>

@property (nonatomic, readonly) bool hasTransport;

@end
