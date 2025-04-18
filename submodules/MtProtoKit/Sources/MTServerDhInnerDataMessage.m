#import "MTServerDhInnerDataMessage.h"

@implementation MTServerDhInnerDataMessage

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce g:(int32_t)g dhPrime:(NSData *)dhPrime gA:(NSData *)gA serverTime:(int32_t)serverTime
{
    self = [super init];
    if (self != nil)
    {
        _nonce = nonce;
        _serverNonce = serverNonce;
        _g = g;
        _dhPrime = dhPrime;
        _gA = gA;
        _serverTime = serverTime;
    }
    return self;
}

@end
