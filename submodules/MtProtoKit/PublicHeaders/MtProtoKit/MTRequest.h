

#import <Foundation/Foundation.h>

@class MTRequestContext;
@class MTRequestErrorContext;
@class MTRpcError;

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
@property (nonatomic) bool hasHighPriority;
@property (nonatomic) bool dependsOnPasswordEntry;
@property (nonatomic) bool passthroughPasswordEntryError;

@property (nonatomic, copy) void (^completed)(id result, NSTimeInterval completionTimestamp, MTRpcError *error);
@property (nonatomic, copy) void (^progressUpdated)(float progress, NSUInteger packetLength);
@property (nonatomic, copy) void (^acknowledgementReceived)();

@property (nonatomic, copy) bool (^shouldContinueExecutionWithErrorContext)(MTRequestErrorContext *errorContext);
@property (nonatomic, copy) bool (^shouldDependOnRequest)(MTRequest *anotherRequest);

- (void)setPayload:(NSData *)payload metadata:(id)metadata shortMetadata:(id)shortMetadata responseParser:(id (^)(NSData *))responseParser;

@end
