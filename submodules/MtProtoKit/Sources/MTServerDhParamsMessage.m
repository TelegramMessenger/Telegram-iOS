#import "MTServerDhParamsMessage.h"

@implementation MTServerDhParamsMessage

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

@implementation MTServerDhParamsFailMessage

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce nextNonceHash:(NSData *)nextNonceHash
{
    self = [super initWithNonce:nonce serverNonce:serverNonce];
    if (self != nil)
    {
        _nextNonceHash = nextNonceHash;
    }
    return self;
}

@end

@implementation MTServerDhParamsOkMessage

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce encryptedResponse:(NSData *)encryptedResponse
{
    self = [super initWithNonce:nonce serverNonce:serverNonce];
    if (self != nil)
    {
        _encryptedResponse = encryptedResponse;
    }
    return self;
}

@end
