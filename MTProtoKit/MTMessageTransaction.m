/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTMessageTransaction.h>

#import <MTProtoKit/MTInternalId.h>

MTInternalIdClass(MTMessageTransaction)

@implementation MTMessageTransaction

- (instancetype)initWithMessagePayload:(NSArray *)messagePayload completion:(void (^)(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, NSDictionary *messageInternalIdToQuickAckId))completion
{
    self = [super init];
    if (self != nil)
    {
        _internalId = [[MTInternalId(MTMessageTransaction) alloc] init];
        
        _messagePayload = messagePayload;
        _completion = completion;
    }
    return self;
}

@end
