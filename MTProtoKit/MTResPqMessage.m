#import "MTResPqMessage.h"

@implementation MTResPqMessage

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce pq:(NSData *)pq serverPublicKeyFingerprints:(NSArray *)serverPublicKeyFingerprints
{
    self = [super init];
    if (self != nil)
    {
        _nonce = nonce;
        _serverNonce = serverNonce;
        _pq = pq;
        _serverPublicKeyFingerprints = serverPublicKeyFingerprints;
    }
    return self;
}

@end
