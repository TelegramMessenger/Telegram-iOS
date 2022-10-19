#import <MtProtoKit/MTMessageTransaction.h>

#import <MtProtoKit/MTInternalId.h>

#import <libkern/OSAtomic.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
MTInternalIdClass(MTMessageTransaction)
#pragma clang diagnostic pop

@implementation MTMessageTransaction

- (instancetype)initWithMessagePayload:(NSArray *)messagePayload prepared:(void (^)(NSDictionary *messageInternalIdToPreparedMessage))prepared failed:(void (^)())failed completion:(void (^)(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, NSDictionary *messageInternalIdToQuickAckId))completion
{
    self = [super init];
    if (self != nil)
    {
        _internalId = [[MTInternalId(MTMessageTransaction) alloc] init];
        
        _messagePayload = messagePayload;
        _completion = [completion copy];
        _prepared = [prepared copy];
        _failed = [failed copy];
    }
    return self;
}

@end
