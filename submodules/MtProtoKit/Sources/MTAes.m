#import "MTAes.h"

#import <CommonCrypto/CommonCrypto.h>

#import <MtProtoKit/MTLogging.h>

# define AES_MAXNR 14
# define AES_BLOCK_SIZE 16

#define N_WORDS (AES_BLOCK_SIZE / sizeof(unsigned long))
typedef struct {
    unsigned long data[N_WORDS];
} aes_block_t;

/* XXX: probably some better way to do this */
#if defined(__i386__) || defined(__x86_64__)
# define UNALIGNED_MEMOPS_ARE_FAST 1
#else
# define UNALIGNED_MEMOPS_ARE_FAST 0
#endif

#if UNALIGNED_MEMOPS_ARE_FAST
# define load_block(d, s)        (d) = *(const aes_block_t *)(s)
# define store_block(d, s)       *(aes_block_t *)(d) = (s)
#else
# define load_block(d, s)        memcpy((d).data, (s), AES_BLOCK_SIZE)
# define store_block(d, s)       memcpy((d), (s).data, AES_BLOCK_SIZE)
#endif

// Every failure path below zeroes the whole output buffer before returning
// false. The IGE feedback passes XOR plaintext blocks into the output, so a
// buffer left untouched after a failed CCCrypt would carry the plaintext
// shifted by one block; a caller that ignores the result must never be able
// to forward that. Release builds compile assert() out, so these checks are
// real branches rather than assertions.
static void MTAesZeroOutput(void *outBytes, int length) {
    if (outBytes != NULL && length > 0) {
        memset(outBytes, 0, (size_t)length);
    }
}

static void MTAesLogFailure(const char *operation, int status) {
    if (MTLogEnabled()) {
        MTLog(@"***** %s: CommonCrypto failed with status %d", operation, status);
    }
}

bool MyAesIgeEncrypt(const void *inBytes, int length, void *outBytes, const void *key, int keyLength, void *iv) {
    if (length < 0 || length % AES_BLOCK_SIZE != 0) {
        MTAesZeroOutput(outBytes, length);
        return false;
    }
    if (length == 0) {
        return true;
    }

    int len;
    size_t n;
    void const *inB;
    void *outB;
    
    unsigned char aesIv[AES_BLOCK_SIZE];
    memcpy(aesIv, iv, AES_BLOCK_SIZE);
    unsigned char ccIv[AES_BLOCK_SIZE];
    memcpy(ccIv, iv + AES_BLOCK_SIZE, AES_BLOCK_SIZE);
    
    assert(((size_t)inBytes | (size_t)outBytes | (size_t)aesIv | (size_t)ccIv) % sizeof(long) ==
           0);
    
    void *tmpInBytes = malloc(length);
    if (tmpInBytes == NULL) {
        MTAesZeroOutput(outBytes, length);
        return false;
    }
    len = length / AES_BLOCK_SIZE;
    inB = inBytes;
    outB = tmpInBytes;
    
    aes_block_t *inp = (aes_block_t *)inB;
    aes_block_t *outp = (aes_block_t *)outB;
    for (n = 0; n < N_WORDS; ++n) {
        outp->data[n] = inp->data[n];
    }
    
    --len;
    inB += AES_BLOCK_SIZE;
    outB += AES_BLOCK_SIZE;
    void const *inBCC = inBytes;
    
    aes_block_t const *iv3p = (aes_block_t *)ccIv;
    
    if (len > 0) {
        while (len) {
            aes_block_t *inp = (aes_block_t *)inB;
            aes_block_t *outp = (aes_block_t *)outB;
            
            for (n = 0; n < N_WORDS; ++n) {
                outp->data[n] = inp->data[n] ^ iv3p->data[n];
            }
            
            iv3p = inBCC;
            --len;
            inBCC += AES_BLOCK_SIZE;
            inB += AES_BLOCK_SIZE;
            outB += AES_BLOCK_SIZE;
        }
    }
    
    size_t realOutLength = 0;
    CCCryptorStatus result = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, 0, key, keyLength, aesIv, tmpInBytes, length, outBytes, length, &realOutLength);
    free(tmpInBytes);
    
    if (result != kCCSuccess || realOutLength != (size_t)length) {
        MTAesLogFailure("MyAesIgeEncrypt", (int)result);
        MTAesZeroOutput(outBytes, length);
        return false;
    }
    
    len = length / AES_BLOCK_SIZE;
    
    aes_block_t const *ivp = inB;
    aes_block_t *iv2p = (aes_block_t *)ccIv;
    
    inB = inBytes;
    outB = outBytes;
    
    while (len) {
        aes_block_t *inp = (aes_block_t *)inB;
        aes_block_t *outp = (aes_block_t *)outB;
        
        for (n = 0; n < N_WORDS; ++n) {
            outp->data[n] ^= iv2p->data[n];
        }
        ivp = outp;
        iv2p = inp;
        --len;
        inB += AES_BLOCK_SIZE;
        outB += AES_BLOCK_SIZE;
    }
    
    memcpy(iv, ivp->data, AES_BLOCK_SIZE);
    memcpy(iv + AES_BLOCK_SIZE, iv2p->data, AES_BLOCK_SIZE);
    return true;
}

bool MyAesIgeDecrypt(const void *inBytes, int length, void *outBytes, const void *key, int keyLength, void *iv) {
    if (length < 0 || length % AES_BLOCK_SIZE != 0) {
        MTAesZeroOutput(outBytes, length);
        return false;
    }
    if (length == 0) {
        return true;
    }
    void *outStart = outBytes;
    
    unsigned char aesIv[AES_BLOCK_SIZE];
    memcpy(aesIv, iv, AES_BLOCK_SIZE);
    unsigned char ccIv[AES_BLOCK_SIZE];
    memcpy(ccIv, iv + AES_BLOCK_SIZE, AES_BLOCK_SIZE);
    
    assert(((size_t)inBytes | (size_t)outBytes | (size_t)aesIv | (size_t)ccIv) % sizeof(long) ==
           0);
    
    CCCryptorRef decryptor = NULL;
    CCCryptorStatus createStatus = CCCryptorCreate(kCCDecrypt, kCCAlgorithmAES128, kCCOptionECBMode, key, keyLength, nil, &decryptor);
    if (createStatus != kCCSuccess || decryptor == NULL) {
        MTAesLogFailure("MyAesIgeDecrypt (create)", (int)createStatus);
        MTAesZeroOutput(outStart, length);
        return false;
    }
    
    int len;
    size_t n;
    
    len = length / AES_BLOCK_SIZE;
    
    aes_block_t *ivp = (aes_block_t *)(aesIv);
    aes_block_t *iv2p = (aes_block_t *)(ccIv);
    
    while (len) {
        aes_block_t tmp;
        aes_block_t *inp = (aes_block_t *)inBytes;
        aes_block_t *outp = (aes_block_t *)outBytes;
        
        for (n = 0; n < N_WORDS; ++n)
            tmp.data[n] = inp->data[n] ^ iv2p->data[n];
        
        size_t dataOutMoved = 0;
        CCCryptorStatus result = CCCryptorUpdate(decryptor, &tmp, AES_BLOCK_SIZE, outBytes, AES_BLOCK_SIZE, &dataOutMoved);
        if (result != kCCSuccess || dataOutMoved != AES_BLOCK_SIZE) {
            MTAesLogFailure("MyAesIgeDecrypt (update)", (int)result);
            CCCryptorRelease(decryptor);
            MTAesZeroOutput(outStart, length);
            return false;
        }
        
        for (n = 0; n < N_WORDS; ++n)
            outp->data[n] ^= ivp->data[n];
        
        ivp = inp;
        iv2p = outp;
        
        inBytes += AES_BLOCK_SIZE;
        outBytes += AES_BLOCK_SIZE;
        
        --len;
    }
    
    memcpy(iv, ivp->data, AES_BLOCK_SIZE);
    memcpy(iv + AES_BLOCK_SIZE, iv2p->data, AES_BLOCK_SIZE);
    
    CCCryptorRelease(decryptor);
    return true;
}

bool MyAesCbcDecrypt(const void *inBytes, int length, void *outBytes, const void *key, int keyLength, void *iv) {
    if (length < 0) {
        return false;
    }
    size_t outLength = 0;
    CCCryptorStatus status = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, 0, key, keyLength, iv, inBytes, length, outBytes, length, &outLength);
    if (status != kCCSuccess || outLength != (size_t)length) {
        MTAesLogFailure("MyAesCbcDecrypt", (int)status);
        MTAesZeroOutput(outBytes, length);
        return false;
    }
    return true;
}

static void ctr128_inc(unsigned char *counter)
{
    uint32_t n = 16, c = 1;
    
    do {
        --n;
        c += counter[n];
        counter[n] = (uint8_t)c;
        c >>= 8;
    } while (n);
}

static void ctr128_inc_aligned(unsigned char *counter)
{
    size_t *data, c, d, n;
    const union {
        long one;
        char little;
    } is_endian = {
        1
    };
    
    if (is_endian.little || ((size_t)counter % sizeof(size_t)) != 0) {
        ctr128_inc(counter);
        return;
    }
    
    data = (size_t *)counter;
    c = 1;
    n = 16 / sizeof(size_t);
    do {
        --n;
        d = data[n] += c;
        /* did addition carry? */
        c = ((d - c) ^ d) >> (sizeof(size_t) * 8 - 1);
    } while (n);
}


@interface MTAesCtr () {
    CCCryptorRef _cryptor;
    
    unsigned char _ivec[16] __attribute__((aligned(16)));
    unsigned int _num;
    unsigned char _ecount[16] __attribute__((aligned(16)));
}

@end

@implementation MTAesCtr

- (instancetype)initWithKey:(const void *)key keyLength:(int)keyLength iv:(const void *)iv decrypt:(bool)decrypt {
    self = [super init];
    if (self != nil) {
        _num = 0;
        memset(_ecount, 0, 16);
        memcpy(_ivec, iv, 16);
        
        if (![self createCryptorWithKey:key keyLength:keyLength]) {
            return nil;
        }
    }
    return self;
}

- (instancetype)initWithKey:(const void *)key keyLength:(int)keyLength iv:(const void *)iv ecount:(void *)ecount num:(uint32_t)num {
    self = [super init];
    if (self != nil) {
        _num = num;
        memcpy(_ecount, ecount, 16);
        memcpy(_ivec, iv, 16);
        
        if (![self createCryptorWithKey:key keyLength:keyLength]) {
            return nil;
        }
    }
    return self;
}

// Without a cryptor _ecount would stay all-zero and encryptIn:out:len: would
// copy its input through unchanged, so a failed create must fail the init.
- (bool)createCryptorWithKey:(const void *)key keyLength:(int)keyLength {
    CCCryptorStatus status = CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES128, kCCOptionECBMode, key, keyLength, nil, &_cryptor);
    if (status != kCCSuccess || _cryptor == NULL) {
        MTAesLogFailure("MTAesCtr (create)", (int)status);
        _cryptor = NULL;
        return false;
    }
    return true;
}

// Advances the keystream by one block into _ecount.
- (bool)nextKeystreamBlock {
    size_t dataOutMoved = 0;
    CCCryptorStatus status = CCCryptorUpdate(_cryptor, _ivec, 16, _ecount, 16, &dataOutMoved);
    if (status != kCCSuccess || dataOutMoved != 16) {
        MTAesLogFailure("MTAesCtr (update)", (int)status);
        return false;
    }
    return true;
}

- (void)dealloc {
    if (_cryptor) {
        CCCryptorRelease(_cryptor);
    }
}

- (uint32_t)num {
    return _num;
}

- (void *)ecount {
    return _ecount;
}

- (void)getIv:(void *)iv {
    memcpy(iv, _ivec, 16);
}

// On a keystream failure the not-yet-processed output is zeroed and false is
// returned; the input is never copied through.
- (bool)encryptIn:(const unsigned char *)in out:(unsigned char *)out len:(size_t)len {
    unsigned int n;
    size_t l = 0;
    
    assert(in);
    assert(out);
    assert(_num < 16);
    
    n = _num;
    
    if (16 % sizeof(size_t) == 0) { /* always true actually */
        do {
            while (n && len) {
                *(out++) = *(in++) ^ _ecount[n];
                --len;
                n = (n + 1) % 16;
            }
            
            if (((size_t)in|(size_t)out|(size_t)_ivec)%sizeof(size_t) != 0)
                break;
            
            while (len >= 16) {
                if (![self nextKeystreamBlock]) {
                    memset(out, 0, len);
                    return false;
                }
                ctr128_inc_aligned(_ivec);
                for (n = 0; n < 16; n += sizeof(size_t)) {
                    *(size_t *)(out + n) =
                    *(size_t *)(in + n) ^ *(size_t *)(_ecount + n);
                }
                len -= 16;
                out += 16;
                in += 16;
                n = 0;
            }
            if (len) {
                if (![self nextKeystreamBlock]) {
                    memset(out, 0, len);
                    return false;
                }
                ctr128_inc_aligned(_ivec);
                while (len--) {
                    out[n] = in[n] ^ _ecount[n];
                    ++n;
                }
            }
            _num = n;
            return true;
        } while (0);
    }
    /* the rest would be commonly eliminated by x86* compiler */
    
    while (l < len) {
        if (n == 0) {
            if (![self nextKeystreamBlock]) {
                memset(out + l, 0, len - l);
                return false;
            }
            ctr128_inc(_ivec);
        }
        out[l] = in[l] ^ _ecount[n];
        ++l;
        n = (n + 1) % 16;
    }
    
    _num = n;
    return true;
}

@end
