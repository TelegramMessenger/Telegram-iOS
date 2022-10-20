#import <MtProtoKit/MTMessageEncryptionKey.h>

#import <MtProtoKit/MTEncryption.h>

@implementation MTMessageEncryptionKey

+ (instancetype)messageEncryptionKeyForAuthKey:(NSData *)authKey messageKey:(NSData *)messageKey toClient:(bool)toClient
{
#ifdef DEBUG
    NSAssert(authKey != nil, @"authKey should not be nil");
    NSAssert(messageKey != nil, @"message key should not be nil");
#endif
    
    if (authKey == nil || authKey.length == 0 || messageKey == nil || messageKey.length == 0)
        return nil;

    int x = toClient ? 8 : 0;
    
    NSData *sha1_a = nil;
    {
        NSMutableData *data = [[NSMutableData alloc] init];
        [data appendData:messageKey];
        [data appendBytes:(((int8_t *)authKey.bytes) + x) length:32];
        sha1_a = MTSha1(data);
    }
    
    NSData *sha1_b = nil;
    {
        NSMutableData *data = [[NSMutableData alloc] init];
        [data appendBytes:(((int8_t *)authKey.bytes) + 32 + x) length:16];
        [data appendData:messageKey];
        [data appendBytes:(((int8_t *)authKey.bytes) + 48 + x) length:16];
        sha1_b = MTSha1(data);
    }
    
    NSData *sha1_c = nil;
    {
        NSMutableData *data = [[NSMutableData alloc] init];
        [data appendBytes:(((int8_t *)authKey.bytes) + 64 + x) length:32];
        [data appendData:messageKey];
        sha1_c = MTSha1(data);
    }
    
    NSData *sha1_d = nil;
    {
        NSMutableData *data = [[NSMutableData alloc] init];
        [data appendData:messageKey];
        [data appendBytes:(((int8_t *)authKey.bytes) + 96 + x) length:32];
        sha1_d = MTSha1(data);
    }
    
    NSMutableData *aesKey = [[NSMutableData alloc] init];
    [aesKey appendBytes:(((int8_t *)sha1_a.bytes)) length:8];
    [aesKey appendBytes:(((int8_t *)sha1_b.bytes) + 8) length:12];
    [aesKey appendBytes:(((int8_t *)sha1_c.bytes) + 4) length:12];
    
    NSMutableData *aesIv = [[NSMutableData alloc] init];
    [aesIv appendBytes:(((int8_t *)sha1_a.bytes) + 8) length:12];
    [aesIv appendBytes:(((int8_t *)sha1_b.bytes)) length:8];
    [aesIv appendBytes:(((int8_t *)sha1_c.bytes) + 16) length:4];
    [aesIv appendBytes:(((int8_t *)sha1_d.bytes)) length:8];
    
    MTMessageEncryptionKey *result = [[MTMessageEncryptionKey alloc] init];
    result->_key = [[NSData alloc] initWithData:aesKey];
    result->_iv = [[NSData alloc] initWithData:aesIv];
    
    return result;
}

+ (instancetype)messageEncryptionKeyV2ForAuthKey:(NSData *)authKey messageKey:(NSData *)messageKey toClient:(bool)toClient {
#ifdef DEBUG
    NSAssert(authKey != nil, @"authKey should not be nil");
    NSAssert(messageKey != nil, @"message key should not be nil");
#endif
    
    if (authKey == nil || authKey.length == 0 || messageKey == nil || messageKey.length == 0)
        return nil;
    
    int xValue = toClient ? 8 : 0;
    
    NSMutableData *sha256_a_data = [[NSMutableData alloc] init];
    [sha256_a_data appendData:messageKey];
    [sha256_a_data appendBytes:authKey.bytes + xValue length:36];
    
    NSData *sha256_a = MTSha256(sha256_a_data);
    
    NSMutableData *sha256_b_data = [[NSMutableData alloc] init];
    [sha256_b_data appendBytes:authKey.bytes + 40 + xValue length:36];
    [sha256_b_data appendData:messageKey];
    
    NSData *sha256_b = MTSha256(sha256_b_data);
    
    NSMutableData *aesKey = [[NSMutableData alloc] init];
    [aesKey appendBytes:sha256_a.bytes + 0 length:8];
    [aesKey appendBytes:sha256_b.bytes + 8 length:16];
    [aesKey appendBytes:sha256_a.bytes + 24 length:8];
    
    NSMutableData *aesIv = [[NSMutableData alloc] init];
    [aesIv appendBytes:sha256_b.bytes + 0 length:8];
    [aesIv appendBytes:sha256_a.bytes + 8 length:16];
    [aesIv appendBytes:sha256_b.bytes + 24 length:8];
    
    MTMessageEncryptionKey *result = [[MTMessageEncryptionKey alloc] init];
    result->_key = [[NSData alloc] initWithData:aesKey];
    result->_iv = [[NSData alloc] initWithData:aesIv];
    
    return result;
}

- (instancetype)initWithKey:(NSData *)key iv:(NSData *)iv
{
    self = [super init];
    if (self != nil)
    {
        _key = key;
        _iv = iv;
    }
    return self;
}

@end
