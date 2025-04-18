

#import <Foundation/Foundation.h>

@interface MTMessageTransaction : NSObject

@property (nonatomic, strong, readonly) id internalId;

/*
 * Can be invoked multiple times in case message transaction maps to multiple different transport transactions
 */
@property (nonatomic, copy) void (^completion)(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, NSDictionary *messageInternalIdToQuickAckId);
@property (nonatomic, copy) void (^prepared)(NSDictionary *messageInternalIdToPreparedMessage);
@property (nonatomic, copy) void (^failed)();

@property (nonatomic, strong) NSArray *messagePayload;
@property (nonatomic) bool allowServiceMode;
@property (nonatomic) bool requiresEncryption;

- (instancetype)initWithMessagePayload:(NSArray *)messagePayload prepared:(void (^)(NSDictionary *messageInternalIdToPreparedMessage))prepared failed:(void (^)())failed completion:(void (^)(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, NSDictionary *messageInternalIdToQuickAckId))completion;

@end
