#import <MtProtoKit/MTRequestErrorContext.h>

@implementation MTRequestPendingVerificationData

- (instancetype)initWithNonce:(NSString *)nonce {
    self = [super init];
    if (self != nil) {
        _nonce = nonce;
    }
    return self;
}

@end

@implementation MTRequestPendingRecaptchaVerificationData

- (instancetype)initWithSiteKey:(NSString *)siteKey {
    self = [super init];
    if (self != nil) {
        _siteKey = siteKey;
    }
    return self;
}

@end

@implementation MTRequestErrorContext

@end
