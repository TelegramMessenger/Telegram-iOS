#import <MtProtoKit/MTEncryption.h>

#import <MtProtoKit/MTLogging.h>
#import <MtProtoKit/MTKeychain.h>

#import <CommonCrypto/CommonCrypto.h>
#import <CommonCrypto/CommonDigest.h>

#import <EncryptionProvider/EncryptionProvider.h>

#import "MTAes.h"
#import "MTRsa.h"

#import "MTBuffer.h"

#import "MTBufferReader.h"

NSData *MTSha1(NSData *data)
{
    uint8_t digest[20];
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    
    return [[NSData alloc] initWithBytes:digest length:20];
}

NSData *MTSubdataSha1(NSData *data, NSUInteger offset, NSUInteger length)
{
    uint8_t digest[20];
    CC_SHA1(((uint8_t *)data.bytes) + offset, (CC_LONG)length, digest);
    
    return [[NSData alloc] initWithBytes:digest length:20];
}

void MTRawSha1(void const *inData, NSUInteger length, void *outData)
{
    CC_SHA1(inData, (CC_LONG)length, outData);
}

NSData *MTSha256(NSData *data)
{
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    
    return [[NSData alloc] initWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
}

void MTRawSha256(void const *inData, NSUInteger length, void *outData)
{
    CC_SHA256(inData, (CC_LONG)length, outData);
}

#if defined(_MSC_VER)

#define FORCE_INLINE    __forceinline

#include <stdlib.h>

#define ROTL32(x,y)     _rotl(x,y)
#define ROTL64(x,y)     _rotl64(x,y)

#define BIG_CONSTANT(x) (x)

// Other compilers

#else   // defined(_MSC_VER)

#define FORCE_INLINE __attribute__((always_inline))

static inline uint32_t rotl32 ( uint32_t x, int8_t r )
{
    return (x << r) | (x >> (32 - r));
}

#define ROTL32(x,y)     rotl32(x,y)
#define ROTL64(x,y)     rotl64(x,y)

#define BIG_CONSTANT(x) (x##LLU)

#endif // !defined(_MSC_VER)

//-----------------------------------------------------------------------------
// Block read - if your platform needs to do endian-swapping or can only
// handle aligned reads, do the conversion here

static FORCE_INLINE uint32_t getblock ( const uint32_t * p, int i )
{
    return p[i];
}

//-----------------------------------------------------------------------------
// Finalization mix - force all bits of a hash block to avalanche

static FORCE_INLINE uint32_t fmix ( uint32_t h )
{
    h ^= h >> 16;
    h *= 0x85ebca6b;
    h ^= h >> 13;
    h *= 0xc2b2ae35;
    h ^= h >> 16;
    
    return h;
}

//----------

static void MurmurHash3_x86_32 ( const void * key, int len,
                                uint32_t seed, void * out )
{
    const uint8_t * data = (const uint8_t*)key;
    const int nblocks = len / 4;
    
    uint32_t h1 = seed;
    
    const uint32_t c1 = 0xcc9e2d51;
    const uint32_t c2 = 0x1b873593;
    
    //----------
    // body
    
    const uint32_t * blocks = (const uint32_t *)(data + nblocks*4);
    
    for(int i = -nblocks; i; i++)
    {
        uint32_t k1 = getblock(blocks,i);
        
        k1 *= c1;
        k1 = ROTL32(k1,15);
        k1 *= c2;
        
        h1 ^= k1;
        h1 = ROTL32(h1,13);
        h1 = h1*5+0xe6546b64;
    }
    
    //----------
    // tail
    
    const uint8_t * tail = (const uint8_t*)(data + nblocks*4);
    
    uint32_t k1 = 0;
    
    switch(len & 3)
    {
        case 3: k1 ^= tail[2] << 16;
        case 2: k1 ^= tail[1] << 8;
        case 1: k1 ^= tail[0];
            k1 *= c1; k1 = ROTL32(k1,15); k1 *= c2; h1 ^= k1;
    };
    
    //----------
    // finalization
    
    h1 ^= len;
    
    h1 = fmix(h1);
    
    *(uint32_t*)out = h1;
}

int32_t MTMurMurHash32(const void *bytes, int length)
{
    int32_t result = 0;
    MurmurHash3_x86_32(bytes, length, -137723950, &result);
    
    return result;
}

void MTAesEncryptInplace(NSMutableData *data, NSData *key, NSData *iv)
{
    unsigned char aesIv[16 * 2];
    memcpy(aesIv, iv.bytes, iv.length);
    
    void *outData = malloc(data.length);
    MyAesIgeEncrypt(data.bytes, (int)data.length, outData, key.bytes, (int)key.length, aesIv);
    memcpy(data.mutableBytes, outData, data.length);
    free(outData);
}

void MTAesEncryptInplaceAndModifyIv(NSMutableData *data, NSData *key, NSMutableData *iv)
{
    unsigned char aesIv[16 * 2];
    memcpy(aesIv, iv.bytes, iv.length);
    
    void *outData = malloc(data.length);
    MyAesIgeEncrypt(data.bytes, (int)data.length, outData, key.bytes, (int)key.length, aesIv);
    memcpy(data.mutableBytes, outData, data.length);
    free(outData);
    
    memcpy(iv.mutableBytes, aesIv, 16 * 2);
}

void MTAesEncryptBytesInplaceAndModifyIv(void *data, NSInteger length, NSData *key, void *iv) {
    unsigned char aesIv[32];
    memcpy(aesIv, iv, 32);
    
    void *outData = malloc(length);
    MyAesIgeEncrypt(data, (int)length, outData, key.bytes, (int)key.length, aesIv);
    memcpy(data, outData, length);
    free(outData);
    
    memcpy(iv, aesIv, 32);
}

void MTAesEncryptRaw(void const *data, void *outData, NSInteger length, void const *key, void const *iv) {
    unsigned char aesIv[32];
    memcpy(aesIv, iv, 32);
    
    MyAesIgeEncrypt(data, (int)length, outData, key, 32, aesIv);
}

void MTAesDecryptRaw(void const *data, void *outData, NSInteger length, void const *key, void const *iv) {
    unsigned char aesIv[32];
    memcpy(aesIv, iv, 32);
    
    MyAesIgeDecrypt(data, (int)length, outData, key, 32, aesIv);
}

void MTAesDecryptInplaceAndModifyIv(NSMutableData *data, NSData *key, NSMutableData *iv)
{
    unsigned char aesIv[16 * 2];
    memcpy(aesIv, iv.bytes, iv.length);
    
    void *outData = malloc(data.length);
    MyAesIgeDecrypt(data.bytes, (int)data.length, outData, key.bytes, (int)key.length, aesIv);
    memcpy(data.mutableBytes, outData, data.length);
    free(outData);
    
    memcpy(iv.mutableBytes, aesIv, 16 * 2);
}

void MTAesDecryptBytesInplaceAndModifyIv(void *data, NSInteger length, NSData *key, void *iv) {
    unsigned char aesIv[16 * 2];
    memcpy(aesIv, iv, 16 * 2);
    
    void *outData = malloc(length);
    MyAesIgeDecrypt(data, (int)length, outData, key.bytes, (int)key.length, aesIv);
    memcpy(data, outData, length);
    free(outData);
    
    memcpy(iv, aesIv, 16 * 2);
}

void MTAesDecryptRawInplaceAndModifyIv(void *data, NSInteger length, void *key, void *iv) {
    unsigned char aesIv[16 * 2];
    memcpy(aesIv, iv, 16 * 2);
    
    void *outData = malloc(length);
    MyAesIgeDecrypt(data, (int)length, outData, key, 32, aesIv);
    memcpy(data, outData, length);
    free(outData);
    
    memcpy(iv, aesIv, 16 * 2);
}

NSData *MTAesEncrypt(NSData *data, NSData *key, NSData *iv)
{
    if (key == nil || iv == nil)
    {
        if (MTLogEnabled()) {
            MTLog(@"***** MTAesEncrypt: empty key or iv");
        }
        return nil;
    }
    
    unsigned char aesIv[16 * 2];
    memcpy(aesIv, iv.bytes, iv.length);
    
    void *outData = malloc(data.length);
    MyAesIgeEncrypt(data.bytes, (int)data.length, outData, key.bytes, (int)key.length, aesIv);
    return [[NSData alloc] initWithBytesNoCopy:outData length:data.length freeWhenDone:true];
}

NSData *MTAesDecrypt(NSData *data, NSData *key, NSData *iv)
{
    if (key == nil || iv == nil)
    {
        if (MTLogEnabled()) {
            MTLog(@"***** MTAesEncrypt: empty key or iv");
        }
        return nil;
    }
    
    NSMutableData *resultData = [[NSMutableData alloc] initWithLength:data.length];
    
    unsigned char aesIv[16 * 2];
    memcpy(aesIv, iv.bytes, iv.length);
    MyAesIgeDecrypt(data.bytes, (int)data.length, resultData.mutableBytes, key.bytes, (int)key.length, aesIv);
    
    return resultData;
}

NSData *MTRsaEncrypt(id<EncryptionProvider> provider, NSString *publicKey, NSData *data)
{
#if TARGET_OS_IOS
    return [provider rsaEncryptWithPublicKey:publicKey data:data];
    /*NSMutableData *updatedData = [[NSMutableData alloc] initWithData:data];
    while (updatedData.length < 256) {
        uint8_t zero = 0;
        [updatedData replaceBytesInRange:NSMakeRange(0, 0) withBytes:&zero length:1];
    }
    return [MTRsa encryptData:updatedData publicKey:publicKey];*/
#else
    return [provider macosRSAEncrypt:publicKey data:data];
#endif
}

NSData *MTExp(id<EncryptionProvider> provider, NSData *base, NSData *exp, NSData *modulus)
{
    id<MTBignumContext> context = [provider createBignumContext];
    
    id<MTBignum> bnBase = [context create];
    [context assignBinTo:bnBase value:base];
    [context setConstantTime:bnBase];
    
    id<MTBignum> bnExp = [context create];
    [context assignBinTo:bnExp value:exp];
    [context setConstantTime:bnExp];
    
    id<MTBignum> bnModulus = [context create];
    [context assignBinTo:bnModulus value:modulus];
    [context setConstantTime:bnModulus];
    
    id<MTBignum> bnRes = [context create];
    [context setConstantTime:bnRes];
    
    [context modExpInto:bnRes a:bnBase b:bnExp mod:bnModulus];
    
    NSData *result = [context getBin:bnRes];
    
    return result;
}

NSData *MTModSub(id<EncryptionProvider> provider, NSData *a, NSData *b, NSData *modulus) {
    id<MTBignumContext> context = [provider createBignumContext];
    
    id<MTBignum> bnA = [context create];
    [context assignBinTo:bnA value:a];
    
    id<MTBignum> bnB = [context create];
    [context assignBinTo:bnB value:b];
    
    id<MTBignum> bnModulus = [context create];
    [context assignBinTo:bnModulus value:modulus];
    
    id<MTBignum> bnRes = [context create];
    
    [context modSubInto:bnRes a:bnA b:bnB mod:bnModulus];
    
    return [context getBin:bnRes];
}

NSData *MTModMul(id<EncryptionProvider> provider, NSData *a, NSData *b, NSData *modulus) {
    id<MTBignumContext> context = [provider createBignumContext];
    
    id<MTBignum> bnA = [context create];
    [context assignBinTo:bnA value:a];
    
    id<MTBignum> bnB = [context create];
    [context assignBinTo:bnB value:b];
    
    id<MTBignum> bnModulus = [context create];
    [context assignBinTo:bnModulus value:modulus];
    
    id<MTBignum> bnRes = [context create];
    
    [context modMulInto:bnRes a:bnA b:bnB mod:bnModulus];
    
    return [context getBin:bnRes];
}

NSData *MTMul(id<EncryptionProvider> provider, NSData *a, NSData *b) {
    id<MTBignumContext> context = [provider createBignumContext];
    
    id<MTBignum> bnA = [context create];
    [context assignBinTo:bnA value:a];
    
    id<MTBignum> bnB = [context create];
    [context assignBinTo:bnB value:b];
    
    id<MTBignum> bnRes = [context create];
    
    [context mulInto:bnRes a:bnA b:bnB];
    
    return [context getBin:bnRes];
}

NSData *MTAdd(id<EncryptionProvider> provider, NSData *a, NSData *b) {
    id<MTBignumContext> context = [provider createBignumContext];
    
    id<MTBignum> bnA = [context create];
    [context assignBinTo:bnA value:a];
    
    id<MTBignum> bnB = [context create];
    [context assignBinTo:bnB value:b];
    
    id<MTBignum> bnRes = [context create];
    
    [context addInto:bnRes a:bnA b:bnB];
    
    return [context getBin:bnRes];
}

bool MTIsZero(id<EncryptionProvider> provider, NSData *value) {
    id<MTBignumContext> context = [provider createBignumContext];
    
    id<MTBignum> bnA = [context create];
    [context assignBinTo:bnA value:value];
    
    return [context isZero:bnA];
}

bool MTCheckIsSafeB(id<EncryptionProvider> provider, NSData *b, NSData *p) {
    id<MTBignumContext> context = [provider createBignumContext];
    
    id<MTBignum> bnB = [context create];
    [context assignBinTo:bnB value:b];
    
    id<MTBignum> bnP = [context create];
    [context assignBinTo:bnP value:p];
    
    id<MTBignum> bnZero = [context create];
    [context assignZeroTo:bnZero];
    
    return [context compare:bnB with:bnZero] == 1 && [context compare:bnB with:bnP] == -1;
}

static inline uint64_t mygcd(uint64_t a, uint64_t b)
{
    while (a != 0 && b != 0)
    {
        while ((b & 1) == 0)
        {
            b >>= 1;
        }
        
        while ((a & 1) == 0)
        {
            a >>= 1;
        }
        
        if (a > b)
            a -= b;
        else
            b -= a;
    }
    return b == 0 ? a : b;
}

bool MTFactorize(uint64_t what, uint64_t *resA, uint64_t *resB)
{
    int it = 0;
    uint64_t g = 0;
    for (int i = 0; i < 3 || it < 1000; i++)
    {
        int q = ((lrand48() & 15) + 17) % what;
        uint64_t x = (uint64_t)lrand48 () % (what - 1) + 1, y = x;
        int lim = 1 << (i + 18);
        int j;
        for (j = 1; j < lim; j++)
        {
            ++it;
            unsigned long long a = x, b = x, c = (unsigned long long)q;
            while (b)
            {
                if (b & 1)
                {
                    c += a;
                    if (c >= what)
                    {
                        c -= what;
                    }
                }
                a += a;
                if (a >= what)
                {
                    a -= what;
                }
                b >>= 1;
            }
            x = c;
            unsigned long long z = x < y ? what + x - y : x - y;
            g = mygcd(z, what);
            if (g != 1)
            {
                break;
            }
            if (!(j & (j - 1)))
            {
                y = x;
            }
        }
        
        if (g > 1 && g < what)
            break;
    }
    
    if (g > 1 && g < what)
    {
        uint64_t p1 = g;
        uint64_t p2 = what / g;
        if (p1 > p2)
        {
            uint64_t tmp = p1;
            p1 = p2;
            p2 = tmp;
        }
        
        if (resA != NULL)
            *resA = p1;
        if (resB != NULL)
            *resB = p2;
        
        return true;
    }
    else
    {
        if (MTLogEnabled()) {
            MTLog(@"Factorization failed for %lld", (long long int)what);
        }
        
        return false;
    }
}

bool MTCheckIsSafeG(unsigned int g)
{
    return g >= 2 && g <= 7;
}

static NSString *hexStringFromData(NSData *data)
{
    NSMutableString *string = [[NSMutableString alloc] initWithCapacity:data.length * 2];
    for (NSUInteger i = 0; i < data.length; i++)
    {
        [string appendFormat:@"%02x", ((uint8_t *)data.bytes)[i]];
    }
    return string;
}

bool MTCheckIsSafePrime(id<EncryptionProvider> provider, NSData *numberBytes, id<MTKeychain> keychain)
{
    NSString *primeKey = [[NSString alloc] initWithFormat:@"isPrimeSafe_%@", hexStringFromData(numberBytes)];
    
    NSNumber *nCachedResult = [keychain objectForKey:primeKey group:@"primes"];
    if (nCachedResult != nil) {
        return [nCachedResult boolValue];
    }
    
    if (numberBytes.length != 256) {
        return false;
    }
    
    if (!(((uint8_t *)numberBytes.bytes)[0] & (1 << 7))) {
        return false;
    }
    
    unsigned char goodPrime0[] = {
        0xc7, 0x1c, 0xae, 0xb9, 0xc6, 0xb1, 0xc9, 0x04, 0x8e, 0x6c, 0x52, 0x2f,
        0x70, 0xf1, 0x3f, 0x73, 0x98, 0x0d, 0x40, 0x23, 0x8e, 0x3e, 0x21, 0xc1,
        0x49, 0x34, 0xd0, 0x37, 0x56, 0x3d, 0x93, 0x0f, 0x48, 0x19, 0x8a, 0x0a,
        0xa7, 0xc1, 0x40, 0x58, 0x22, 0x94, 0x93, 0xd2, 0x25, 0x30, 0xf4, 0xdb,
        0xfa, 0x33, 0x6f, 0x6e, 0x0a, 0xc9, 0x25, 0x13, 0x95, 0x43, 0xae, 0xd4,
        0x4c, 0xce, 0x7c, 0x37, 0x20, 0xfd, 0x51, 0xf6, 0x94, 0x58, 0x70, 0x5a,
        0xc6, 0x8c, 0xd4, 0xfe, 0x6b, 0x6b, 0x13, 0xab, 0xdc, 0x97, 0x46, 0x51,
        0x29, 0x69, 0x32, 0x84, 0x54, 0xf1, 0x8f, 0xaf, 0x8c, 0x59, 0x5f, 0x64,
        0x24, 0x77, 0xfe, 0x96, 0xbb, 0x2a, 0x94, 0x1d, 0x5b, 0xcd, 0x1d, 0x4a,
        0xc8, 0xcc, 0x49, 0x88, 0x07, 0x08, 0xfa, 0x9b, 0x37, 0x8e, 0x3c, 0x4f,
        0x3a, 0x90, 0x60, 0xbe, 0xe6, 0x7c, 0xf9, 0xa4, 0xa4, 0xa6, 0x95, 0x81,
        0x10, 0x51, 0x90, 0x7e, 0x16, 0x27, 0x53, 0xb5, 0x6b, 0x0f, 0x6b, 0x41,
        0x0d, 0xba, 0x74, 0xd8, 0xa8, 0x4b, 0x2a, 0x14, 0xb3, 0x14, 0x4e, 0x0e,
        0xf1, 0x28, 0x47, 0x54, 0xfd, 0x17, 0xed, 0x95, 0x0d, 0x59, 0x65, 0xb4,
        0xb9, 0xdd, 0x46, 0x58, 0x2d, 0xb1, 0x17, 0x8d, 0x16, 0x9c, 0x6b, 0xc4,
        0x65, 0xb0, 0xd6, 0xff, 0x9c, 0xa3, 0x92, 0x8f, 0xef, 0x5b, 0x9a, 0xe4,
        0xe4, 0x18, 0xfc, 0x15, 0xe8, 0x3e, 0xbe, 0xa0, 0xf8, 0x7f, 0xa9, 0xff,
        0x5e, 0xed, 0x70, 0x05, 0x0d, 0xed, 0x28, 0x49, 0xf4, 0x7b, 0xf9, 0x59,
        0xd9, 0x56, 0x85, 0x0c, 0xe9, 0x29, 0x85, 0x1f, 0x0d, 0x81, 0x15, 0xf6,
        0x35, 0xb1, 0x05, 0xee, 0x2e, 0x4e, 0x15, 0xd0, 0x4b, 0x24, 0x54, 0xbf,
        0x6f, 0x4f, 0xad, 0xf0, 0x34, 0xb1, 0x04, 0x03, 0x11, 0x9c, 0xd8, 0xe3,
        0xb9, 0x2f, 0xcc, 0x5b
    };
    
    if (memcmp(goodPrime0, numberBytes.bytes, 256) == 0) {
        return true;
    }
    
    id<MTBignumContext> context = [provider createBignumContext];
    
    id<MTBignum> bnNumber = [context create];
    [context assignBinTo:bnNumber value:numberBytes];
    
    int result = [context isPrime:bnNumber numberOfChecks:30];
    
    if (result == 1) {
        id<MTBignum> bnNumberOne = [context create];
        [context assignOneTo:bnNumberOne];
        
        id<MTBignum> bnNumberMinusOne = [context create];
        [context subInto:bnNumberMinusOne a:bnNumber b:bnNumberOne];
        
        id<MTBignum> bnNumberMinusOneDivByTwo = [context create];
        [context rightShift1Bit:bnNumberMinusOneDivByTwo a:bnNumberMinusOne];
        
        result = [context isPrime:bnNumberMinusOneDivByTwo numberOfChecks:30];
    }
    
    [keychain setObject:@(result == 1) forKey:primeKey group:@"primes"];
    
    return result == 1;
}

bool MTCheckIsSafeGAOrB(id<EncryptionProvider> provider, NSData *gAOrB, NSData *p) {
    id<MTBignumContext> context = [provider createBignumContext];
    
    id<MTBignum> bnNumber = [context create];
    [context assignBinTo:bnNumber value:gAOrB];
    
    id<MTBignum> bnP = [context create];
    [context assignBinTo:bnP value:p];
    
    id<MTBignum> bnOne = [context create];
    [context assignOneTo:bnOne];
    
    bool result = false;
    
    if ([context compare:bnNumber with:bnOne] == 1) {
        id<MTBignum> bnPMinusOne = [context create];
        [context subInto:bnPMinusOne a:bnP b:bnOne];
        
        if ([context compare:bnNumber with:bnPMinusOne] == -1) {
            id<MTBignum> n2 = [context create];
            [context assignWordTo:n2 value:2];
            
            id<MTBignum> n2048_minus_64 = [context create];
            [context assignWordTo:n2048_minus_64 value:2048 - 64];
            
            id<MTBignum> n2_to_2048_minus_64 = [context create];
            [context expInto:n2_to_2048_minus_64 a:n2 b:n2048_minus_64];
            
            id<MTBignum> dh_prime_minus_n2_to_2048_minus_64 = [context create];
            [context subInto:dh_prime_minus_n2_to_2048_minus_64 a:bnP b:n2_to_2048_minus_64];
            
            if ([context compare:bnNumber with:n2_to_2048_minus_64] == 1 &&
                [context compare:bnNumber with:dh_prime_minus_n2_to_2048_minus_64] == -1) {
                result = true;
            }
        }
    }
    
    return result;
}

bool MTCheckMod(id<EncryptionProvider> provider, NSData *numberBytes, unsigned int g, id<MTKeychain> keychain)
{
    NSString *modKey = [[NSString alloc] initWithFormat:@"isPrimeModSafe_%@_%d", hexStringFromData(numberBytes), g];
    NSNumber *nCachedResult = [keychain objectForKey:modKey group:@"primes"];
    if (nCachedResult != nil) {
        return [nCachedResult boolValue];
    }
    
    id<MTBignumContext> context = [provider createBignumContext];
    
    id<MTBignum> bnNumber = [context create];
    [context assignBinTo:bnNumber value:numberBytes];
    
    bool result = false;
    
    switch (g) {
        case 2: {
            unsigned long modResult = [context modWord:bnNumber mod:8];
            result = modResult == 7;
            
            break;
        }
        case 3: {
            unsigned long modResult = [context modWord:bnNumber mod:3];
            result = modResult == 2;
            
            break;
        }
        case 4: {
            result = true;
            
            break;
        }
        case 5: {
            unsigned long modResult = [context modWord:bnNumber mod:5];
            result = modResult == 1 || modResult == 4;
            
            break;
        }
        case 6: {
            unsigned long modResult = [context modWord:bnNumber mod:24];
            result = modResult == 19 || modResult == 23;
            
            break;
        }
        case 7: {
            unsigned long modResult = [context modWord:bnNumber mod:7];
            result = modResult == 3 || modResult == 5 || modResult == 6;
            
            break;
        }
        default:
            break;
    }
    
    [keychain setObject:@(result) forKey:modKey group:@"primes"];
    
    return result;
}

NSData *MTAesCtrDecrypt(NSData *data, NSData *key, NSData *iv) {
    MTAesCtr *ctr = [[MTAesCtr alloc] initWithKey:key.bytes keyLength:32 iv:iv.bytes decrypt:true];
    NSMutableData *outData = [[NSMutableData alloc] initWithLength:data.length];
    [ctr encryptIn:data.bytes out:outData.mutableBytes len:data.length];
    return outData;
}

uint64_t MTRsaFingerprint(id<EncryptionProvider> provider, NSString *key) {
    id<MTBignumContext> context = [provider createBignumContext];
    id<MTRsaPublicKey> rsaKey = [provider parseRSAPublicKey:key];
    if (rsaKey == nil) {
        return 0;
    }
    
    id<MTBignum> rsaKeyN = [context rsaGetN:rsaKey];
    id<MTBignum> rsaKeyE = [context rsaGetE:rsaKey];
    
    NSData *nData = [context getBin:rsaKeyN];
    NSData *eData = [context getBin:rsaKeyE];
    
    MTBuffer *buffer = [[MTBuffer alloc] init];
    [buffer appendTLBytes:nData];
    [buffer appendTLBytes:eData];
    
    NSData *sha1Data = MTSha1(buffer.data);
    static uint8_t sha1Buffer[20];
    [sha1Data getBytes:sha1Buffer length:20];
    
    uint64_t fingerprint = (((uint64_t) sha1Buffer[19]) << 56) |
    (((uint64_t) sha1Buffer[18]) << 48) |
    (((uint64_t) sha1Buffer[17]) << 40) |
    (((uint64_t) sha1Buffer[16]) << 32) |
    (((uint64_t) sha1Buffer[15]) << 24) |
    (((uint64_t) sha1Buffer[14]) << 16) |
    (((uint64_t) sha1Buffer[13]) << 8) |
    ((uint64_t) sha1Buffer[12]);
    
    return fingerprint;
}

NSData *MTRsaEncryptPKCS1OAEP(id<EncryptionProvider> provider, NSString *key, NSData *data) {
    return [provider rsaEncryptPKCS1OAEPWithPublicKey:key data:data];
}

static NSData *decrypt_TL_data(id<EncryptionProvider> provider, unsigned char buffer[256]) {
    NSString *keyString = @"-----BEGIN RSA PUBLIC KEY-----\n"
"MIIBCgKCAQEAyr+18Rex2ohtVy8sroGPBwXD3DOoKCSpjDqYoXgCqB7ioln4eDCF\n"
"fOBUlfXUEvM/fnKCpF46VkAftlb4VuPDeQSS/ZxZYEGqHaywlroVnXHIjgqoxiAd\n"
"192xRGreuXIaUKmkwlM9JID9WS2jUsTpzQ91L8MEPLJ/4zrBwZua8W5fECwCCh2c\n"
"9G5IzzBm+otMS/YKwmR1olzRCyEkyAEjXWqBI9Ftv5eG8m0VkBzOG655WIYdyV0H\n"
"fDK/NWcvGqa0w/nriMD6mDjKOryamw0OP9QuYgMN0C9xMW9y8SmP4h92OAWodTYg\n"
"Y1hZCxdv6cs5UnW9+PWvS+WIbkh+GaWYxwIDAQAB\n"
"-----END RSA PUBLIC KEY-----";
    
    id<MTRsaPublicKey> rsaKey = [provider parseRSAPublicKey:keyString];
    if (rsaKey == nil) {
        return nil;
    }
    
    uint8_t *bytes = buffer;
    
    id<MTBignumContext> context = [provider createBignumContext];
    
    id<MTBignum> x = [context create];
    id<MTBignum> y = [context create];
    
    [context assignBinTo:x value:[NSData dataWithBytesNoCopy:buffer length:256 freeWhenDone:false]];
    
    id<MTBignum> rsaKeyN = [context rsaGetN:rsaKey];
    id<MTBignum> rsaKeyE = [context rsaGetE:rsaKey];
    
    NSData *result = nil;
    
    if ([context modExpInto:y a:x b:rsaKeyE mod:rsaKeyN]) {
        NSData *yBytes = [context getBin:y];
        unsigned l = 256 - (unsigned)yBytes.length;
        assert(l >= 0);
        
        [yBytes getBytes:bytes + l length:256 - l];
        
        NSMutableData *iv = [[NSMutableData alloc] initWithLength:16];
        memcpy(iv.mutableBytes, bytes + 16, 16);
        
        NSData *encryptedBytes = [[NSData alloc] initWithBytes:bytes + 32 length:256 - 32];
        
        NSData *keyBytes = [[NSData alloc] initWithBytes:bytes length:32];
        
        NSMutableData *decryptedBytes = [[NSMutableData alloc] initWithLength:encryptedBytes.length];
        MyAesCbcDecrypt(encryptedBytes.bytes, (int)encryptedBytes.length, decryptedBytes.mutableBytes, keyBytes.bytes, (int)keyBytes.length, iv.mutableBytes);
        
        if (decryptedBytes == nil) {
            return nil;
        }
        
        NSData *sha256Bytes = MTSha256([decryptedBytes subdataWithRange:NSMakeRange(0, 256 - 32 - 16)]);
        
        unsigned char sha256_out[32];
        [sha256Bytes getBytes:sha256_out length:32];
        
        NSData *sha256Part = [sha256Bytes subdataWithRange:NSMakeRange(0, 16)];
        NSData *testSha256 = [decryptedBytes subdataWithRange:NSMakeRange(decryptedBytes.length - 16, 16)];
        
        if ([sha256Part isEqualToData:testSha256]) {
            memcpy(bytes + 32, decryptedBytes.bytes, 256 - 32);
            
            unsigned data_len = *(unsigned *) (bytes + 32);
            if (data_len && data_len <= 256 - 32 - 16 && !(data_len & 3)) {
                result = [NSData dataWithBytes:buffer + 32 + 4 length:data_len];
            } else {
                if (MTLogEnabled()) {
                    MTLog(@"TL data length field invalid - %d", data_len);
                }
            }
        } else {
            if (MTLogEnabled()) {
                MTLog(@"RSA signature check FAILED (SHA256 mismatch)");
            }
        }
    }

    return result;
}

@implementation MTBackupDatacenterAddress

- (instancetype)initWithDatacenterId:(int32_t)datacenterId ip:(NSString *)ip port:(int32_t)port secret:(NSData *)secret {
    self = [super init];
    if (self != nil) {
        _datacenterId = datacenterId;
        _ip = ip;
        _port = port;
        _secret = secret;
    }
    return self;
}

@end

@implementation MTBackupDatacenterData

- (instancetype)initWithTimestamp:(int32_t)timestamp expirationDate:(int32_t)expirationDate addressList:(NSArray<MTBackupDatacenterAddress *> *)addressList {
    self = [super init];
    if (self != nil) {
        _timestamp = timestamp;
        _expirationDate = expirationDate;
        _addressList = addressList;
    }
    return self;
}

@end

MTBackupDatacenterData *MTIPDataDecode(id<EncryptionProvider> provider, NSData *data, NSString *phoneNumber) {
    if (data.length < 256) {
        return nil;
    }
    unsigned char buffer[256];
    memcpy(buffer, data.bytes, 256);
    NSData *result = decrypt_TL_data(provider, buffer);
    
    if (result != nil) {
        MTBufferReader *reader = [[MTBufferReader alloc] initWithData:result];
        int32_t signature = 0;
        if (![reader readInt32:&signature]) {
            return nil;
        }
        if (signature == 0xd997c3c5) {
            int32_t timestamp = 0;
            int32_t expirationDate = 0;
            int32_t datacenterId = 0;
            if (![reader readInt32:&timestamp]) {
                return nil;
            }
            if (![reader readInt32:&expirationDate]) {
                return nil;
            }
            if (![reader readInt32:&datacenterId]) {
                return nil;
            }
            int32_t vectorSignature = 0;
            if (![reader readInt32:&vectorSignature]) {
                return nil;
            }
            if (vectorSignature != 0x1cb5c415) {
                return nil;
            }
            
            NSMutableArray<MTBackupDatacenterAddress *> *addressList = [[NSMutableArray alloc] init];
            int32_t count = 0;
            if (![reader readInt32:&count]) {
                return nil;
            }
            
            for (int i = 0; i < count; i++) {
                int32_t ip = 0;
                int32_t port = 0;
                if (![reader readInt32:&ip]) {
                    return nil;
                }
                if (![reader readInt32:&port]) {
                    return nil;
                }
                [addressList addObject:[[MTBackupDatacenterAddress alloc] initWithDatacenterId:datacenterId ip:[NSString stringWithFormat:@"%d.%d.%d.%d", (int)((ip >> 24) & 0xFF), (int)((ip >> 16) & 0xFF), (int)((ip >> 8) & 0xFF), (int)((ip >> 0) & 0xFF)] port:port secret:nil]];
            }
            
            return [[MTBackupDatacenterData alloc] initWithTimestamp:timestamp expirationDate:expirationDate addressList:addressList];
        } else if (signature == 0x5a592a6c) {
            int32_t timestamp = 0;
            int32_t expirationDate = 0;
            if (![reader readInt32:&timestamp]) {
                return nil;
            }
            if (![reader readInt32:&expirationDate]) {
                return nil;
            }
            
            NSMutableArray<MTBackupDatacenterAddress *> *addressList = [[NSMutableArray alloc] init];
            int32_t count = 0;
            if (![reader readInt32:&count]) {
                return nil;
            }
            
            for (int32_t i = 0; i < count; i++) {
                int32_t signature = 0;
                if (![reader readInt32:&signature]) {
                    return nil;
                }
                if (signature != 0x4679b65f) {
                    return nil;
                }
                NSString *phonePrefixRules = nil;
                if (![reader readTLString:&phonePrefixRules]) {
                    return nil;
                }
                int32_t datacenterId = 0;
                if (![reader readInt32:&datacenterId]) {
                    return nil;
                }
                
                int32_t ipCount = 0;
                if (![reader readInt32:&ipCount]) {
                    return nil;
                }
                
                NSMutableArray<MTBackupDatacenterAddress *> *ruleAddressList = [[NSMutableArray alloc] init];
                
                for (int j = 0; j < ipCount; j++) {
                    int32_t signature = 0;
                    if (![reader readInt32:&signature]) {
                        return nil;
                    }
                    if (signature == 0xd433ad73) {
                        int32_t ip = 0;
                        int32_t port = 0;
                        if (![reader readInt32:&ip]) {
                            return nil;
                        }
                        if (![reader readInt32:&port]) {
                            return nil;
                        }
                        [ruleAddressList addObject:[[MTBackupDatacenterAddress alloc] initWithDatacenterId:datacenterId ip:[NSString stringWithFormat:@"%d.%d.%d.%d", (int)((ip >> 24) & 0xFF), (int)((ip >> 16) & 0xFF), (int)((ip >> 8) & 0xFF), (int)((ip >> 0) & 0xFF)] port:port secret:nil]];
                    } else if (signature == 0x37982646) {
                        int32_t ip = 0;
                        int32_t port = 0;
                        if (![reader readInt32:&ip]) {
                            return nil;
                        }
                        if (![reader readInt32:&port]) {
                            return nil;
                        }
                        NSData *secret = nil;
                        if (![reader readTLBytes:&secret]) {
                            return nil;
                        }
                        [ruleAddressList addObject:[[MTBackupDatacenterAddress alloc] initWithDatacenterId:datacenterId ip:[NSString stringWithFormat:@"%d.%d.%d.%d", (int)((ip >> 24) & 0xFF), (int)((ip >> 16) & 0xFF), (int)((ip >> 8) & 0xFF), (int)((ip >> 0) & 0xFF)] port:port secret:secret]];
                    } else {
                        return nil;
                    }
                }
                
                bool includeIp = true;
                for (NSString *rule in [phonePrefixRules componentsSeparatedByString:@","]) {
                    if (rule.length == 0) {
                        includeIp = true;
                    } else if ([rule characterAtIndex:0] == '+' && [phoneNumber hasPrefix:[rule substringFromIndex:1]]) {
                        includeIp = true;
                    } else if ([rule characterAtIndex:0] == '-' && [phoneNumber hasPrefix:[rule substringFromIndex:1]]) {
                        includeIp = false;
                    } else {
                        includeIp = false;
                    }
                }
                if (includeIp) {
                    [addressList addObjectsFromArray:ruleAddressList];
                }
            }
            
            return [[MTBackupDatacenterData alloc] initWithTimestamp:timestamp expirationDate:expirationDate addressList:addressList];
        } else {
            return nil;
        }
    } else {
        return nil;
    }
}

NSData * _Nullable MTPBKDF2(NSData * _Nonnull data, NSData * _Nonnull salt, int rounds) {
    if (rounds < 2) {
        return nil;
    }
    const size_t hashLength = 64;
    NSMutableData *result = [[NSMutableData alloc] initWithLength:hashLength];
    CCStatus status = CCKeyDerivationPBKDF(kCCPBKDF2, data.bytes, data.length, salt.bytes, salt.length, kCCPRFHmacAlgSHA512, rounds, result.mutableBytes, hashLength);
    if (status != kCCSuccess) {
        return nil;
    }
    return result;
}
