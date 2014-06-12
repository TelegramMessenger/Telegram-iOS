/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTDatacenterSaltInfo : NSObject <NSCoding>

@property (nonatomic, readonly) int64_t salt;
@property (nonatomic, readonly) int64_t firstValidMessageId;
@property (nonatomic, readonly) int64_t lastValidMessageId;

- (instancetype)initWithSalt:(int64_t)salt firstValidMessageId:(int64_t)firstValidMessageId lastValidMessageId:(int64_t)lastValidMessageId;

- (int64_t)validMessageCountAfterId:(int64_t)messageId;
- (bool)isValidFutureSaltForMessageId:(int64_t)messageId;

@end
