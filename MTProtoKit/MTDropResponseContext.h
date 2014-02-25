/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTDropResponseContext : NSObject

@property (nonatomic, readonly) int64_t dropMessageId;
@property (nonatomic) int64_t messageId;
@property (nonatomic) int32_t messageSeqNo;

- (instancetype)initWithDropMessageId:(int64_t)dropMessageId;

@end
