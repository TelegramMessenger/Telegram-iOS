#import <OpenSSLEncryptionProvider/OpenSSLEncryptionProvider.h>

#import <openssl/bn.h>
#import <openssl/rsa.h>
#import <openssl/pem.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTBignumImpl : NSObject <MTBignum, NSCopying> {
    @public
    BIGNUM *_value;
}

@end

@implementation MTBignumImpl

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _value = BN_new();
    }
    return self;
}

- (instancetype)initWithValue:(BIGNUM *)value {
    self = [super init];
    if (self != nil) {
        _value = value;
    }
    return self;
}

- (void)dealloc {
    BN_clear_free(_value);
}

- (instancetype)copyWithZone:(NSZone * _Nullable)__unused zone {
    return [[MTBignumImpl alloc] initWithValue:BN_dup(_value)];
}

@end

@interface MTRsaPublicKeyImpl : NSObject <MTRsaPublicKey> {
    @public
    RSA *_value;
}

@end

@implementation MTRsaPublicKeyImpl

- (instancetype)initWithValue:(RSA *)value {
    self = [super init];
    if (self != nil) {
        _value = value;
    }
    return self;
}

- (void)dealloc {
    RSA_free(_value);
}

@end

@interface MTBignumContextImpl : NSObject <MTBignumContext> {
    BN_CTX *_context;
}

@end

@implementation MTBignumContextImpl

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _context = BN_CTX_new();
    }
    return self;
}

- (void)dealloc {
    BN_CTX_free(_context);
}

- (id<MTBignum>)create {
    return [[MTBignumImpl alloc] init];
}

- (id<MTBignum>)clone:(id<MTBignum>)other {
    assert([other isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *otherImpl = (MTBignumImpl *)other;
    return [otherImpl copy];
}

- (void)setConstantTime:(id<MTBignum>)other {
    assert([other isKindOfClass:[MTBignumImpl class]]);
    #ifndef TELEGRAM_USE_BORINGSSL
    MTBignumImpl *otherImpl = (MTBignumImpl *)other;
    BN_set_flags(otherImpl->_value, BN_FLG_CONSTTIME);
    #endif
}

- (void)assignWordTo:(id<MTBignum>)bignum value:(unsigned long)value {
    assert([bignum isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *bignumImpl = (MTBignumImpl *)bignum;
    
    BN_set_word(bignumImpl->_value, value);
}

- (void)assignHexTo:(id<MTBignum>)bignum value:(NSString *)value {
    assert([bignum isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *bignumImpl = (MTBignumImpl *)bignum;
    
    BN_hex2bn(&bignumImpl->_value, [value UTF8String]);
}

- (void)assignBinTo:(id<MTBignum>)bignum value:(NSData *)value {
    assert([bignum isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *bignumImpl = (MTBignumImpl *)bignum;
    
    BN_bin2bn(value.bytes, value.length, bignumImpl->_value);
}

- (void)assignOneTo:(id<MTBignum>)bignum {
    assert([bignum isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *bignumImpl = (MTBignumImpl *)bignum;
    
    BN_one(bignumImpl->_value);
}

- (void)assignZeroTo:(id<MTBignum>)bignum {
    assert([bignum isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *bignumImpl = (MTBignumImpl *)bignum;
    
    BN_zero(bignumImpl->_value);
}

- (bool)isOne:(id<MTBignum>)bignum {
    assert([bignum isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *bignumImpl = (MTBignumImpl *)bignum;
    
    return BN_is_one(bignumImpl->_value);
}

- (bool)isZero:(id<MTBignum>)bignum {
    assert([bignum isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *bignumImpl = (MTBignumImpl *)bignum;
    
    return BN_is_zero(bignumImpl->_value);
}

- (NSData *)getBin:(id<MTBignum>)bignum {
    assert([bignum isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *bignumImpl = (MTBignumImpl *)bignum;
    
    int numBytes = BN_num_bytes(bignumImpl->_value);
    NSMutableData *data = [[NSMutableData alloc] initWithLength:numBytes];
    BN_bn2bin(bignumImpl->_value, data.mutableBytes);
    
    return data;
}

- (int)isPrime:(id<MTBignum>)bignum numberOfChecks:(int)numberOfChecks {
    assert([bignum isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *bignumImpl = (MTBignumImpl *)bignum;
    
    return BN_is_prime_ex(bignumImpl->_value, numberOfChecks, _context, NULL);
}

- (int)compare:(id<MTBignum>)a with:(id<MTBignum>)b {
    assert([a isKindOfClass:[MTBignumImpl class]]);
    assert([b isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *aImpl = (MTBignumImpl *)a;
    MTBignumImpl *bImpl = (MTBignumImpl *)b;
    
    return BN_cmp(aImpl->_value, bImpl->_value);
}

- (bool)modAddInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b mod:(id<MTBignum>)mod {
    assert([result isKindOfClass:[MTBignumImpl class]]);
    assert([a isKindOfClass:[MTBignumImpl class]]);
    assert([b isKindOfClass:[MTBignumImpl class]]);
    assert([mod isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *resultImpl = (MTBignumImpl *)result;
    MTBignumImpl *aImpl = (MTBignumImpl *)a;
    MTBignumImpl *bImpl = (MTBignumImpl *)b;
    MTBignumImpl *modImpl = (MTBignumImpl *)mod;
    
    return BN_mod_add(resultImpl->_value, aImpl->_value, bImpl->_value, modImpl->_value, _context) != 0;
}

- (bool)modSubInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b mod:(id<MTBignum>)mod {
    assert([result isKindOfClass:[MTBignumImpl class]]);
    assert([a isKindOfClass:[MTBignumImpl class]]);
    assert([b isKindOfClass:[MTBignumImpl class]]);
    assert([mod isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *resultImpl = (MTBignumImpl *)result;
    MTBignumImpl *aImpl = (MTBignumImpl *)a;
    MTBignumImpl *bImpl = (MTBignumImpl *)b;
    MTBignumImpl *modImpl = (MTBignumImpl *)mod;
    
    return BN_mod_sub(resultImpl->_value, aImpl->_value, bImpl->_value, modImpl->_value, _context) != 0;
}

- (bool)modMulInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b mod:(id<MTBignum>)mod {
    assert([result isKindOfClass:[MTBignumImpl class]]);
    assert([a isKindOfClass:[MTBignumImpl class]]);
    assert([b isKindOfClass:[MTBignumImpl class]]);
    assert([mod isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *resultImpl = (MTBignumImpl *)result;
    MTBignumImpl *aImpl = (MTBignumImpl *)a;
    MTBignumImpl *bImpl = (MTBignumImpl *)b;
    MTBignumImpl *modImpl = (MTBignumImpl *)mod;
    
    return BN_mod_mul(resultImpl->_value, aImpl->_value, bImpl->_value, modImpl->_value, _context) != 0;
}

- (bool)modExpInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b mod:(id<MTBignum>)mod {
    assert([result isKindOfClass:[MTBignumImpl class]]);
    assert([a isKindOfClass:[MTBignumImpl class]]);
    assert([b isKindOfClass:[MTBignumImpl class]]);
    assert([mod isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *resultImpl = (MTBignumImpl *)result;
    MTBignumImpl *aImpl = (MTBignumImpl *)a;
    MTBignumImpl *bImpl = (MTBignumImpl *)b;
    MTBignumImpl *modImpl = (MTBignumImpl *)mod;
    
    return BN_mod_exp(resultImpl->_value, aImpl->_value, bImpl->_value, modImpl->_value, _context) != 0;
}

- (bool)addInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b {
    assert([result isKindOfClass:[MTBignumImpl class]]);
    assert([a isKindOfClass:[MTBignumImpl class]]);
    assert([b isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *resultImpl = (MTBignumImpl *)result;
    MTBignumImpl *aImpl = (MTBignumImpl *)a;
    MTBignumImpl *bImpl = (MTBignumImpl *)b;
    
    return BN_add(resultImpl->_value, aImpl->_value, bImpl->_value) != 0;
}

- (bool)subInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b {
    assert([result isKindOfClass:[MTBignumImpl class]]);
    assert([a isKindOfClass:[MTBignumImpl class]]);
    assert([b isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *resultImpl = (MTBignumImpl *)result;
    MTBignumImpl *aImpl = (MTBignumImpl *)a;
    MTBignumImpl *bImpl = (MTBignumImpl *)b;
    
    return BN_sub(resultImpl->_value, aImpl->_value, bImpl->_value) != 0;
}

- (bool)mulInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b {
    assert([result isKindOfClass:[MTBignumImpl class]]);
    assert([a isKindOfClass:[MTBignumImpl class]]);
    assert([b isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *resultImpl = (MTBignumImpl *)result;
    MTBignumImpl *aImpl = (MTBignumImpl *)a;
    MTBignumImpl *bImpl = (MTBignumImpl *)b;
    
    return BN_mul(resultImpl->_value, aImpl->_value, bImpl->_value, _context) != 0;
}

- (bool)expInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b {
    assert([result isKindOfClass:[MTBignumImpl class]]);
    assert([a isKindOfClass:[MTBignumImpl class]]);
    assert([b isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *resultImpl = (MTBignumImpl *)result;
    MTBignumImpl *aImpl = (MTBignumImpl *)a;
    MTBignumImpl *bImpl = (MTBignumImpl *)b;
    
    return BN_exp(resultImpl->_value, aImpl->_value, bImpl->_value, _context) != 0;
}

- (bool)modInverseInto:(id<MTBignum>)result a:(id<MTBignum>)a mod:(id<MTBignum>)mod {
    assert([result isKindOfClass:[MTBignumImpl class]]);
    assert([a isKindOfClass:[MTBignumImpl class]]);
    assert([mod isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *resultImpl = (MTBignumImpl *)result;
    MTBignumImpl *aImpl = (MTBignumImpl *)a;
    MTBignumImpl *modImpl = (MTBignumImpl *)mod;
    
    return BN_mod_inverse(resultImpl->_value, aImpl->_value, modImpl->_value, _context) != 0;
}

- (unsigned long)modWord:(id<MTBignum>)a mod:(unsigned long)mod {
    assert([a isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *aImpl = (MTBignumImpl *)a;
    
    return BN_mod_word(aImpl->_value, mod);
}

- (bool)rightShift1Bit:(id<MTBignum>)result a:(id<MTBignum>)a {
    assert([result isKindOfClass:[MTBignumImpl class]]);
    assert([a isKindOfClass:[MTBignumImpl class]]);
    MTBignumImpl *resultImpl = (MTBignumImpl *)result;
    MTBignumImpl *aImpl = (MTBignumImpl *)a;
    return BN_rshift1(resultImpl->_value, aImpl->_value);
}

- (id<MTBignum>)rsaGetE:(id<MTRsaPublicKey>)publicKey {
    assert([publicKey isKindOfClass:[MTRsaPublicKeyImpl class]]);
    MTRsaPublicKeyImpl *publicKeyImpl = publicKey;
    return [[MTBignumImpl alloc] initWithValue:BN_dup(RSA_get0_e(publicKeyImpl->_value))];
}

- (id<MTBignum>)rsaGetN:(id<MTRsaPublicKey>)publicKey {
    assert([publicKey isKindOfClass:[MTRsaPublicKeyImpl class]]);
    MTRsaPublicKeyImpl *publicKeyImpl = publicKey;
    return [[MTBignumImpl alloc] initWithValue:BN_dup(RSA_get0_n(publicKeyImpl->_value))];
}

@end

@implementation OpenSSLEncryptionProvider

- (id<MTBignumContext>)createBignumContext {
    return [[MTBignumContextImpl alloc] init];
}

- (NSData * _Nullable)rsaEncryptWithPublicKey:(NSString *)publicKey data:(NSData *)data {
    MTRsaPublicKeyImpl *rsaKey = [self parseRSAPublicKey:publicKey];
    if (rsaKey == nil) {
        return nil;
    }
    
    MTBignumContextImpl *context = [[MTBignumContextImpl alloc] init];
    
    MTBignumImpl *a = (MTBignumImpl *)[context create];
    [context assignBinTo:a value:data];
    
    MTBignumImpl *r = (MTBignumImpl *)[context create];
    [context modExpInto:r a:a b:[context rsaGetE:rsaKey] mod:[context rsaGetN:rsaKey]];
     
    return [context getBin:r];
}

- (NSData * _Nullable)rsaEncryptPKCS1OAEPWithPublicKey:(NSString *)publicKey data:(NSData *)data {
    MTRsaPublicKeyImpl *rsaKey = [self parseRSAPublicKey:publicKey];
    if (rsaKey == nil) {
        return nil;
    }
    
    NSMutableData *outData = [[NSMutableData alloc] initWithLength:data.length + 2048];
    
    int encryptedLength = RSA_public_encrypt((int)data.length, data.bytes, outData.mutableBytes, rsaKey->_value, RSA_PKCS1_OAEP_PADDING);
    
    if (encryptedLength < 0) {
        return nil;
    }
    
    assert(encryptedLength <= outData.length);
    [outData setLength:encryptedLength];
    
    return outData;
}

- (id<MTRsaPublicKey>)parseRSAPublicKey:(NSString *)publicKey {
    BIO *keyBio = BIO_new(BIO_s_mem());
    NSData *keyData = [publicKey dataUsingEncoding:NSUTF8StringEncoding];
    if (keyData == nil) {
        return nil;
    }
    BIO_write(keyBio, keyData.bytes, (int)keyData.length);
    RSA *rsaKey = PEM_read_bio_RSAPublicKey(keyBio, NULL, NULL, NULL);
    BIO_free(keyBio);
    if (rsaKey == nil) {
        return nil;
    }
    return [[MTRsaPublicKeyImpl alloc] initWithValue:rsaKey];
}

-(NSData *)macosRSAEncrypt:(NSString *) publicKey data: (NSData *)data {
    BIO *keyBio = BIO_new(BIO_s_mem());
    const char *keyData = [publicKey UTF8String];
    BIO_write(keyBio, keyData, (int)publicKey.length);
    RSA *rsaKey = PEM_read_bio_RSAPublicKey(keyBio, NULL, NULL, NULL);
    BIO_free(keyBio);
    
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM *a = BN_bin2bn(data.bytes, (int)data.length, NULL);
    BIGNUM *r = BN_new();
    
    
    
    BN_mod_exp(r, a, RSA_get0_e(rsaKey), RSA_get0_n(rsaKey), ctx);
    
    unsigned char *res = malloc((size_t)BN_num_bytes(r));
    int resLen = (int)(BN_bn2bin(r, res));
    
    BN_CTX_free(ctx);
    BN_free(a);
    BN_free(r);
    
    RSA_free(rsaKey);
    
    NSData *result = [[NSData alloc] initWithBytesNoCopy:res length:(NSUInteger)resLen freeWhenDone:true];
    
    return result;
}

@end

NS_ASSUME_NONNULL_END
