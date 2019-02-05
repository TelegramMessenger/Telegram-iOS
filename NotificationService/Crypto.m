#import "Crypto.h"
#import <CommonCrypto/CommonCrypto.h>

#define AES_BLOCK_SIZE 16

#define N_WORDS (AES_BLOCK_SIZE / sizeof(unsigned long))
typedef struct {
    unsigned long data[N_WORDS];
} aes_block_t;

static void MyAesIgeDecrypt(const void *inBytes, int length, void *outBytes, const void *key, int keyLength, void *iv) {
    unsigned char aesIv[AES_BLOCK_SIZE];
    memcpy(aesIv, iv, AES_BLOCK_SIZE);
    unsigned char ccIv[AES_BLOCK_SIZE];
    memcpy(ccIv, iv + AES_BLOCK_SIZE, AES_BLOCK_SIZE);
    
    assert(((size_t)inBytes | (size_t)outBytes | (size_t)aesIv | (size_t)ccIv) % sizeof(long) ==
           0);
    
    CCCryptorRef decryptor = NULL;
    CCCryptorCreate(kCCDecrypt, kCCAlgorithmAES128, kCCOptionECBMode, key, keyLength, nil, &decryptor);
    if (decryptor != NULL) {
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
            assert(result == kCCSuccess);
            assert(dataOutMoved == AES_BLOCK_SIZE);
            
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
    }
}

NSData *MTAesDecrypt(NSData *data, NSData *key, NSData *iv) {
    assert(key != nil && iv != nil);
    
    NSMutableData *resultData = [[NSMutableData alloc] initWithLength:data.length];
    
    unsigned char aesIv[16 * 2];
    memcpy(aesIv, iv.bytes, iv.length);
    MyAesIgeDecrypt(data.bytes, (int)data.length, resultData.mutableBytes, key.bytes, (int)key.length, aesIv);
    
    return resultData;
}
