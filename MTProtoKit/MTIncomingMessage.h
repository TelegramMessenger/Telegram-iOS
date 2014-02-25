/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTIncomingMessage : NSObject

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int32_t seqNo;
@property (nonatomic, readonly) int64_t salt;
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) NSInteger size;
@property (nonatomic, strong, readonly) id body;

- (instancetype)initWithMessageId:(int64_t)messageId seqNo:(int32_t)seqNo salt:(int64_t)salt timestamp:(NSTimeInterval)timestamp size:(NSInteger)size body:(id)body;

@end
