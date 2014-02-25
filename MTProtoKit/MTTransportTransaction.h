/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTTransportTransaction : NSObject

@property (nonatomic, copy, readonly) void (^completion)(bool success, id transactionId);
@property (nonatomic, strong, readonly) NSData *payload;
@property (nonatomic, readonly) bool expectsDataInResponse;
@property (nonatomic, readonly) bool needsQuickAck;

- (instancetype)initWithPayload:(NSData *)payload completion:(void (^)(bool success, id transactionId))completion;
- (instancetype)initWithPayload:(NSData *)payload completion:(void (^)(bool success, id transactionId))completion needsQuickAck:(bool)needsQuickAck expectsDataInResponse:(bool)expectsDataInResponse;

@end
