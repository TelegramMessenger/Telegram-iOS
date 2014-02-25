/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTRequestContext : NSObject

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int32_t messageSeqNo;
@property (nonatomic, strong) id transactionId;
@property (nonatomic) int32_t quickAckId;
@property (nonatomic) bool delivered;
@property (nonatomic) bool willInitializeApi;

- (instancetype)initWithMessageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo transactionId:(id)transactionId quickAckId:(int32_t)quickAckId;

@end
