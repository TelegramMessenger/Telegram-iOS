/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTEncryption.h>

#import <MTProtoKit/MTKeychain.h>

#import <CommonCrypto/CommonCrypto.h>
#import <CommonCrypto/CommonDigest.h>

#include <openssl/bn.h>
#include <openssl/rsa.h>
#include <openssl/evp.h>
#include <openssl/bn.h>
#include <openssl/pem.h>
#include <openssl/err.h>
#include <openssl/sha.h>
#include <openssl/evp.h>
#include <openssl/aes.h>

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

NSData *MTSha256(NSData *data)
{
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    
    return [[NSData alloc] initWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
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

static inline uint64_t rotl64 ( uint64_t x, int8_t r )
{
    return (x << r) | (x >> (64 - r));
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
    AES_KEY aesKey;
    AES_set_encrypt_key(key.bytes, 256, &aesKey);
    unsigned char aesIv[AES_BLOCK_SIZE * 2];
    memcpy(aesIv, iv.bytes, iv.length);
    
    AES_ige_encrypt(data.bytes, (void *)data.bytes, data.length, &aesKey, aesIv, true);
}

void MTAesEncryptInplaceAndModifyIv(NSMutableData *data, NSData *key, NSMutableData *iv)
{
    AES_KEY aesKey;
    AES_set_encrypt_key(key.bytes, 256, &aesKey);
    
    AES_ige_encrypt(data.bytes, (void *)data.bytes, data.length, &aesKey, iv.mutableBytes, true);
}

void MTAesDecryptInplace(NSMutableData *data, NSData *key, NSData *iv)
{
    AES_KEY aesKey;
    AES_set_decrypt_key(key.bytes, 256, &aesKey);
    unsigned char aesIv[AES_BLOCK_SIZE * 2];
    memcpy(aesIv, iv.bytes, iv.length);
    
    AES_ige_encrypt(data.bytes, (void *)data.bytes, data.length, &aesKey, aesIv, false);
}

void MTAesDecryptInplaceAndModifyIv(NSMutableData *data, NSData *key, NSMutableData *iv)
{
    AES_KEY aesKey;
    AES_set_decrypt_key(key.bytes, 256, &aesKey);
    
    AES_ige_encrypt(data.bytes, (void *)data.bytes, data.length, &aesKey, iv.mutableBytes, false);
}

NSData *MTAesEncrypt(NSData *data, NSData *key, NSData *iv)
{
    if (key == nil || iv == nil)
    {
        MTLog(@"***** MTAesEncrypt: empty key or iv");
        return nil;
    }
    AES_KEY aesKey;
    AES_set_encrypt_key(key.bytes, 256, &aesKey);
    unsigned char aesIv[AES_BLOCK_SIZE * 2];
    memcpy(aesIv, iv.bytes, iv.length);
    
    uint8_t *resultBytes = malloc(data.length);
    AES_ige_encrypt(data.bytes, resultBytes, data.length, &aesKey, aesIv, true);
    
    return [[NSData alloc] initWithBytesNoCopy:resultBytes length:data.length freeWhenDone:true];
}

NSData *MTAesDecrypt(NSData *data, NSData *key, NSData *iv)
{
    if (key == nil || iv == nil)
    {
        MTLog(@"***** MTAesEncrypt: empty key or iv");
        return nil;
    }
    AES_KEY aesKey;
    AES_set_decrypt_key(key.bytes, 256, &aesKey);
    unsigned char aesIv[AES_BLOCK_SIZE * 2];
    memcpy(aesIv, iv.bytes, iv.length);
    
    uint8_t *resultBytes = malloc(data.length);
    AES_ige_encrypt(data.bytes, resultBytes, data.length, &aesKey, aesIv, false);
    
    return [[NSData alloc] initWithBytesNoCopy:resultBytes length:data.length freeWhenDone:true];
}

NSData *MTRsaEncrypt(NSString *publicKey, NSData *data)
{
    BIO *keyBio = BIO_new(BIO_s_mem());
    const char *keyData = [publicKey UTF8String];
    BIO_write(keyBio, keyData, (int)publicKey.length);
    RSA *rsaKey = PEM_read_bio_RSAPublicKey(keyBio, NULL, NULL, NULL);
    BIO_free(keyBio);
    
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM *a = BN_bin2bn(data.bytes, (int)data.length, NULL);
    BIGNUM *r = BN_new();
    
    BN_mod_exp(r, a, rsaKey->e, rsaKey->n, ctx);
    
    unsigned char *res = malloc((size_t)BN_num_bytes(r));
    int resLen = BN_bn2bin(r, res);
    
    BN_CTX_free(ctx);
    BN_free(a);
    BN_free(r);
    
    RSA_free(rsaKey);
    
    NSData *result = [[NSData alloc] initWithBytesNoCopy:res length:(NSUInteger)resLen freeWhenDone:true];
    
    return result;
}

NSData *MTExp(NSData *base, NSData *exp, NSData *modulus)
{
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM *bnBase = BN_bin2bn(base.bytes, (int)base.length, NULL);
    BIGNUM *bnExp = BN_bin2bn(exp.bytes, (int)exp.length, NULL);
    BIGNUM *bnModulus = BN_bin2bn(modulus.bytes, (int)modulus.length, NULL);
    
    BIGNUM *bnRes = BN_new();
    
    BN_mod_exp(bnRes, bnBase, bnExp, bnModulus, ctx);
    
    unsigned char *res = malloc((size_t)BN_num_bytes(bnRes));
    int resLen = BN_bn2bin(bnRes, res);
    
    BN_CTX_free(ctx);
    BN_free(bnBase);
    BN_free(bnExp);
    BN_free(bnModulus);
    BN_free(bnRes);
    
    NSData *result = [[NSData alloc] initWithBytes:res length:(NSUInteger)resLen];
    free(res);
    
    return result;
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
        MTLog(@"Factorization failed for %lld", (long long int)what);
        
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

bool MTCheckIsSafePrime(NSData *numberBytes, MTKeychain *keychain)
{
    NSString *primeKey = [[NSString alloc] initWithFormat:@"isPrimeSafe_%@", hexStringFromData(numberBytes)];
    
    NSNumber *nCachedResult = [keychain objectForKey:primeKey group:@"primes"];
    if (nCachedResult != nil)
        return [nCachedResult boolValue];
    
    if (numberBytes.length != 256)
    {
        [[NSUserDefaults standardUserDefaults] setObject:[[NSNumber alloc] initWithBool:false] forKey:primeKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        return false;
    }
    
    if (!(((uint8_t *)numberBytes.bytes)[0] & (1 << 7)))
    {
        [[NSUserDefaults standardUserDefaults] setObject:[[NSNumber alloc] initWithBool:false] forKey:primeKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
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
    
    if (memcmp(goodPrime0, numberBytes.bytes, 256) == 0)
        return true;
    
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM *bnNumber = BN_bin2bn(numberBytes.bytes, (int)numberBytes.length, NULL);
    
    int result = BN_is_prime_ex(bnNumber, 30, ctx, NULL);
    
    if (result == 1)
    {
        BIGNUM *bnNumberMinus1 = BN_new();
        BN_sub(bnNumberMinus1, bnNumber, BN_value_one());
        BIGNUM *bnNumberMinus1DivBy2 = BN_new();
        BN_rshift1(bnNumberMinus1DivBy2, bnNumberMinus1);
        
        result = BN_is_prime_ex(bnNumberMinus1DivBy2, 30, ctx, NULL);
        
        BN_free(bnNumberMinus1);
        BN_free(bnNumberMinus1DivBy2);
    }
    
    BN_free(bnNumber);
    BN_CTX_free(ctx);
    
    [keychain setObject:@(result == 1) forKey:primeKey group:@"primes"];
    
    return result == 1;
}

bool MTCheckIsSafeGAOrB(NSData *gAOrB, NSData *p)
{
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM *bnNumber = BN_bin2bn(gAOrB.bytes, (int)gAOrB.length, NULL);
    BIGNUM *bnP = BN_bin2bn(p.bytes, (int)p.length, NULL);
    
    bool result = false;
    
    if (BN_cmp(bnNumber, BN_value_one()) == 1)
    {
        BIGNUM *pMinus1 = BN_new();
        BN_sub(pMinus1, bnP, BN_value_one());
        
        if (BN_cmp(bnNumber, pMinus1) == -1)
        {
            result = true;
        }
        
        BN_free(pMinus1);
    }
    
    BN_free(bnNumber);
    BN_free(bnP);
    BN_CTX_free(ctx);
    
    return result;
}

bool MTCheckMod(NSData *numberBytes, unsigned int g, MTKeychain *keychain)
{
    NSString *modKey = [[NSString alloc] initWithFormat:@"isPrimeModSafe_%@_%d", hexStringFromData(numberBytes), g];
    NSNumber *nCachedResult = [keychain objectForKey:modKey group:@"primes"];
    if (nCachedResult != nil)
        return [nCachedResult boolValue];
    
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM *bnNumber = BN_bin2bn(numberBytes.bytes, (int)numberBytes.length, NULL);
    
    bool result = false;
    
    switch (g)
    {
        case 2:
        {
            BN_ULONG modResult = BN_mod_word(bnNumber, 8);
            result = modResult == 7;
            
            break;
        }
        case 3:
        {
            BN_ULONG modResult = BN_mod_word(bnNumber, 3);
            result = modResult == 2;
            
            break;
        }
        case 4:
        {
            result = true;
            
            break;
        }
        case 5:
        {
            BN_ULONG modResult = BN_mod_word(bnNumber, 5);
            result = modResult == 1 || modResult == 4;
            
            break;
        }
        case 6:
        {
            BN_ULONG modResult = BN_mod_word(bnNumber, 24);
            result = modResult == 19 || modResult == 23;
            
            break;
        }
        case 7:
        {
            BN_ULONG modResult = BN_mod_word(bnNumber, 7);
            result = modResult == 3 || modResult == 5 || modResult == 6;
            
            break;
        }
        default:
            break;
    }
    
    BN_free(bnNumber);
    BN_CTX_free(ctx);
    
    [keychain setObject:@(result) forKey:modKey group:@"primes"];
    
    return result;
}
