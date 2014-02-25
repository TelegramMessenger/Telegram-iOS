/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTMessageTransaction : NSObject

@property (nonatomic, strong, readonly) id internalId;

/*
 * Can be invoked multiple times in case when message transaction maps to multiple different transport transactions
 */
@property (nonatomic, copy) void (^completion)(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, NSDictionary *messageInternalIdToQuickAckId);

@property (nonatomic, strong) NSArray *messagePayload;
@property (nonatomic) bool allowServiceMode;
@property (nonatomic) bool requiresEncryption;

- (instancetype)initWithMessagePayload:(NSArray *)messagePayload completion:(void (^)(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, NSDictionary *messageInternalIdToQuickAckId))completion;

@end
