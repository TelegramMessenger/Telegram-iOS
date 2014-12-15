/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTOutgoingMessage : NSObject

@property (nonatomic, strong, readonly) id internalId;
@property (nonatomic, strong, readonly) NSData *data;
@property (nonatomic, strong, readonly) id metadata;
@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int32_t messageSeqNo;
@property (nonatomic) bool requiresConfirmation;
@property (nonatomic) bool needsQuickAck;
@property (nonatomic) bool hasHighPriority;
@property (nonatomic) int64_t inResponseToMessageId;

@property (nonatomic, copy) id (^dynamicDecorator)(NSData *currentData, NSMutableDictionary *messageInternalIdToPreparedMessage);

- (instancetype)initWithData:(NSData *)data metadata:(id)metadata;
- (instancetype)initWithData:(NSData *)data metadata:(id)metadata messageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo;

@end
