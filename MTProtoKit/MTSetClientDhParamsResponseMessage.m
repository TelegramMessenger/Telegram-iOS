#import "MTSetClientDhParamsResponseMessage.h"

@implementation MTSetClientDhParamsResponseMessage

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce
{
    self = [super init];
    if (self != nil)
    {
        _nonce = nonce;
        _serverNonce = serverNonce;
    }
    return self;
}

@end

@implementation MTSetClientDhParamsResponseOkMessage

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce nextNonceHash1:(NSData *)nextNonceHash1
{
    self = [super initWithNonce:nonce serverNonce:serverNonce];
    if (self != nil)
    {
        _nextNonceHash1 = nextNonceHash1;
    }
    return self;
}

@end

@implementation MTSetClientDhParamsResponseRetryMessage

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce nextNonceHash2:(NSData *)nextNonceHash2
{
    self = [super initWithNonce:nonce serverNonce:serverNonce];
    if (self != nil)
    {
        _nextNonceHash2 = nextNonceHash2;
    }
    return self;
}

@end

@implementation MTSetClientDhParamsResponseFailMessage

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce nextNonceHash3:(NSData *)nextNonceHash3
{
    self = [super initWithNonce:nonce serverNonce:serverNonce];
    if (self != nil)
    {
        _nextNonceHash3 = nextNonceHash3;
    }
    return self;
}

@end
