/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTPreparedMessage : NSObject

@property (nonatomic, strong, readonly) id internalId;

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int32_t seqNo;
@property (nonatomic, readonly) int64_t salt;
@property (nonatomic, strong, readonly) NSData *data;
@property (nonatomic, readonly) bool requiresConfirmation;
@property (nonatomic, readonly) bool hasHighPriority;
@property (nonatomic, readonly) int64_t inResponseToMessageId;

- (instancetype)initWithData:(NSData *)data messageId:(int64_t)messageId seqNo:(int32_t)seqNo salt:(int64_t)salt requiresConfirmation:(bool)requiresConfirmation hasHighPriority:(bool)hasHighPriority;
- (instancetype)initWithData:(NSData *)data messageId:(int64_t)messageId seqNo:(int32_t)seqNo salt:(int64_t)salt requiresConfirmation:(bool)requiresConfirmation hasHighPriority:(bool)hasHighPriority inResponseToMessageId:(int64_t)inResponseToMessageId;

@end
