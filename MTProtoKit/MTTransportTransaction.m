/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTTransportTransaction.h>

@implementation MTTransportTransaction

- (instancetype)initWithPayload:(NSData *)payload completion:(void (^)(bool success, id transactionId))completion
{
    return [self initWithPayload:payload completion:completion needsQuickAck:false expectsDataInResponse:false];
}

- (instancetype)initWithPayload:(NSData *)payload completion:(void (^)(bool success, id transactionId))completion needsQuickAck:(bool)needsQuickAck expectsDataInResponse:(bool)expectsDataInResponse
{
    self = [super init];
    if (self != nil)
    {
        _payload = payload;
        _completion = completion;
        _needsQuickAck = needsQuickAck;
        _expectsDataInResponse = expectsDataInResponse;
    }
    return self;
}

@end
