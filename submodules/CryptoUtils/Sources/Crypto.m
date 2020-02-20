#include <CryptoUtils/Crypto.h>

#import <CommonCrypto/CommonCrypto.h>

NSData * _Nonnull CryptoMD5(const void * _Nonnull bytes, int count) {
    NSMutableData *result = [[NSMutableData alloc] initWithLength:(NSUInteger)CC_MD5_DIGEST_LENGTH];
    CC_MD5(bytes, (CC_LONG)count, result.mutableBytes);
    return result;
}

NSData * _Nonnull CryptoSHA1(const void * _Nonnull bytes, int count) {
    NSMutableData *result = [[NSMutableData alloc] initWithLength:(NSUInteger)CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(bytes, (CC_LONG)count, result.mutableBytes);
    return result;
}

NSData * _Nonnull CryptoSHA256(const void * _Nonnull bytes, int count) {
    NSMutableData *result = [[NSMutableData alloc] initWithLength:(NSUInteger)CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes, (CC_LONG)count, result.mutableBytes);
    return result;
}

NSData * _Nonnull CryptoSHA512(const void * _Nonnull bytes, int count) {
    NSMutableData *result = [[NSMutableData alloc] initWithLength:(NSUInteger)CC_SHA512_DIGEST_LENGTH];
    CC_SHA512(bytes, (CC_LONG)count, result.mutableBytes);
    return result;
}

@interface IncrementalMD5 () {
    CC_MD5_CTX _ctx;
}

@end

@implementation IncrementalMD5

- (instancetype _Nonnull)init {
    self = [super init];
    if (self != nil) {
        CC_MD5_Init(&_ctx);
    }
    return self;
}

- (void)update:(NSData * _Nonnull)data {
    CC_MD5_Update(&_ctx, data.bytes, (CC_LONG)data.length);
}

- (void)update:(const void *)bytes count:(int)count {
    CC_MD5_Update(&_ctx, bytes, (CC_LONG)count);
}

- (NSData *)complete {
    NSMutableData *result = [[NSMutableData alloc] initWithLength:(NSUInteger)CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(result.mutableBytes, &_ctx);
    return result;
}

@end

NSData * _Nullable CryptoAES(bool encrypt, NSData * _Nonnull key, NSData * _Nonnull iv, NSData * _Nonnull data) {
    if (key.length != 32) {
        return nil;
    }
    if (iv.length != 16) {
        return nil;
    }
    NSMutableData *processedData = [[NSMutableData alloc] initWithLength:data.length];
    size_t processedCount = 0;
    CCStatus status = CCCrypt(encrypt ? kCCEncrypt : kCCDecrypt, kCCAlgorithmAES128, 0, key.bytes, key.length, iv.bytes, data.bytes, data.length, processedData.mutableBytes, processedData.length, &processedCount);
    if (status != kCCSuccess) {
        return nil;
    }
    if (processedCount != (size_t)processedData.length) {
        return nil;
    }
    return processedData;
}
