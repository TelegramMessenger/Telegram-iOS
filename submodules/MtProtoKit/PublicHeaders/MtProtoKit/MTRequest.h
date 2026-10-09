

#import <Foundation/Foundation.h>

@class MTRequestContext;
@class MTRequestErrorContext;
@class MTRpcError;

@interface MTRequestResponseInfo : NSObject

@property (nonatomic, readonly) int32_t networkType;
@property (nonatomic, readonly) double timestamp;
@property (nonatomic, readonly) double duration;

- (instancetype)initWithNetworkType:(int32_t)networkType timestamp:(double)timestamp duration:(double)duration;

@end

@interface MTRequest : NSObject

@property (nonatomic, strong, readonly) id internalId;

@property (nonatomic, strong, readonly) NSData *payload;
@property (nonatomic, strong, readonly) id metadata;
@property (nonatomic, strong, readonly) id shortMetadata;
@property (nonatomic, strong, readonly) id (^responseParser)(NSData *);

@property (nonatomic, strong) NSArray *decorators;
@property (nonatomic) int32_t transactionResetStateVersion;
@property (nonatomic, strong) MTRequestContext *requestContext;
@property (nonatomic, strong) MTRequestErrorContext *errorContext;
/// The request went out under a message id and the server may have run it; cleared when the server
/// answers it with an error after which it goes again. Kept when its message id is forgotten (a
/// transaction that may have failed, a session change), for a handover (`handOverRequests:`).
@property (nonatomic, direct) bool mayHaveReachedServer;
@property (nonatomic) bool hasHighPriority;
@property (nonatomic) bool dependsOnPasswordEntry;
@property (nonatomic) bool passthroughPasswordEntryError;
@property (nonatomic) bool needsTimeoutTimer;
@property (nonatomic) int32_t expectedResponseSize;

@property (nonatomic, copy) void (^completed)(id result, MTRequestResponseInfo *info, MTRpcError *error);
@property (nonatomic, copy) void (^progressUpdated)(float progress, NSUInteger packetLength);
@property (nonatomic, copy) void (^acknowledgementReceived)();

@property (nonatomic, copy) bool (^shouldContinueExecutionWithErrorContext)(MTRequestErrorContext *errorContext);
@property (nonatomic, copy) bool (^shouldDependOnRequest)(MTRequest *anotherRequest);

- (bool)scanNeedsTimeoutTimer __attribute__((objc_direct));
- (MTRequestErrorContext *)scanErrorContext __attribute__((objc_direct));
- (id)scanInternalId __attribute__((objc_direct));

- (void)setPayload:(NSData *)payload metadata:(id)metadata shortMetadata:(id)shortMetadata responseParser:(id (^)(NSData *))responseParser;

@end
