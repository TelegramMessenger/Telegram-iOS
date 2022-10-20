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

- (NSString *)description {
    NSMutableString *fingerprintsString = [[NSMutableString alloc] init];
    for (NSNumber *value in _serverPublicKeyFingerprints) {
        if (fingerprintsString.length != 0) {
            [fingerprintsString appendString:@"\n"];
        }
        [fingerprintsString appendFormat:@"%llx", [value longLongValue]];
    }
    return [NSString stringWithFormat:@"res_pq nonce:%@ serverNonce:%@ pq:%@ fingerprints:%@", _nonce, _serverNonce, _pq, fingerprintsString];
}

@end
