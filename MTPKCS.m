#import "MTPKCS.h"

#include <openssl/x509.h>
#include <openssl/pkcs7.h>

@implementation MTPKCS

- (instancetype)initWithName:(NSString *)name data:(NSData *)data {
    self = [super init];
    if (self != nil) {
        _name = name;
        _data = data;
    }
    return self;
}

+ (MTPKCS * _Nullable)parse:(const unsigned char *)buffer size:(int)size {
    MTPKCS * _Nullable result = nil;
    PKCS7 *pkcs7 = NULL;
    STACK_OF(X509) *signers = NULL;
    
    pkcs7 = d2i_PKCS7(NULL, &buffer, size);
    if (pkcs7 == NULL) {
        return nil;
    }
    
    if (!PKCS7_type_is_signed(pkcs7)) {
        if (pkcs7) {
            PKCS7_free(pkcs7);
        }
        return nil;
    }
    
    signers = PKCS7_get0_signers(pkcs7, NULL, PKCS7_BINARY);
    if (signers == NULL) {
        if (pkcs7) {
            PKCS7_free(pkcs7);
        }
        return nil;
    }
    
    const X509* cert = sk_X509_pop(signers);
    if (cert == NULL) {
        if (signers) {
            sk_X509_free(signers);
        }
        if (pkcs7) {
            PKCS7_free(pkcs7);
        }
        
        return nil;
    }
    
    result = [[MTPKCS alloc] initWithName:[NSString stringWithUTF8String:cert->name] data:[NSData dataWithBytes:cert->cert_info->key->public_key->data length:cert->cert_info->key->public_key->length]];
    
    return result;
}

@end
