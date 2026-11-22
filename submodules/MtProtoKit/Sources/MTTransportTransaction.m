#import <MtProtoKit/MTTransportTransaction.h>

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
