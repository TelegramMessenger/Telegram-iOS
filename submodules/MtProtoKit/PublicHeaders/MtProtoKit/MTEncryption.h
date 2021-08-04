#ifndef MTEncryption_H
#define MTEncryption_H

#import <Foundation/Foundation.h>

#import <EncryptionProvider/EncryptionProvider.h>

#ifdef __cplusplus
extern "C" {
#endif
    
NSData * _Nonnull MTSha1(NSData * _Nonnull data);
NSData * _Nonnull MTSubdataSha1(NSData * _Nonnull data, NSUInteger offset, NSUInteger length);
    
NSData * _Nonnull MTSha256(NSData * _Nonnull data);
    
void MTRawSha1(void const * _Nonnull inData, NSUInteger length, void * _Nonnull outData);
void MTRawSha256(void const * _Nonnull inData, NSUInteger length, void * _Nonnull outData);
    
int32_t MTMurMurHash32(const void * _Nonnull bytes, int length);
    
void MTAesEncryptInplace(NSMutableData * _Nonnull data, NSData * _Nonnull key, NSData * _Nonnull iv);
void MTAesEncryptInplaceAndModifyIv(NSMutableData * _Nonnull data, NSData * _Nonnull key, NSMutableData * _Nonnull iv);
void MTAesEncryptBytesInplaceAndModifyIv(void * _Nonnull data, NSInteger length, NSData * _Nonnull key, void * _Nonnull iv);
void MTAesEncryptRaw(void const * _Nonnull data, void * _Nonnull outData, NSInteger length, void const * _Nonnull key, void const * _Nonnull iv);
void MTAesDecryptRaw(void const * _Nonnull data, void * _Nonnull outData, NSInteger length, void const * _Nonnull key, void const * _Nonnull iv);
void MTAesDecryptInplaceAndModifyIv(NSMutableData * _Nonnull data, NSData * _Nonnull key, NSMutableData * _Nonnull iv);
void MTAesDecryptBytesInplaceAndModifyIv(void * _Nonnull data, NSInteger length, NSData * _Nonnull key, void * _Nonnull iv);
NSData * _Nullable MTAesEncrypt(NSData * _Nonnull data, NSData * _Nonnull key, NSData * _Nonnull iv);
NSData * _Nullable MTAesDecrypt(NSData * _Nonnull data, NSData * _Nonnull key, NSData * _Nonnull iv);
NSData * _Nullable MTRsaEncrypt(id<EncryptionProvider> _Nonnull  provider, NSString * _Nonnull publicKey, NSData * _Nonnull data);
NSData * _Nullable MTExp(id<EncryptionProvider> _Nonnull  provider, NSData * _Nonnull base, NSData * _Nonnull exp, NSData * _Nonnull modulus);
NSData * _Nullable MTModSub(id<EncryptionProvider> _Nonnull  provider, NSData * _Nonnull a, NSData * _Nonnull b, NSData * _Nonnull modulus);
NSData * _Nullable MTModMul(id<EncryptionProvider> _Nonnull  provider, NSData * _Nonnull a, NSData * _Nonnull b, NSData * _Nonnull modulus);
NSData * _Nullable MTMul(id<EncryptionProvider> _Nonnull  provider, NSData * _Nonnull a, NSData * _Nonnull b);
NSData * _Nullable MTAdd(id<EncryptionProvider> _Nonnull  provider, NSData * _Nonnull a, NSData * _Nonnull b);
bool MTFactorize(uint64_t what, uint64_t * _Nonnull resA, uint64_t * _Nonnull resB);
bool MTIsZero(id<EncryptionProvider> _Nonnull  provider, NSData * _Nonnull value);
    
NSData * _Nullable MTAesCtrDecrypt(NSData * _Nonnull data, NSData * _Nonnull key, NSData * _Nonnull iv);
    
@protocol MTKeychain;
bool MTCheckIsSafeG(unsigned int g);
bool MTCheckIsSafeB(id<EncryptionProvider> _Nonnull provider, NSData * _Nonnull b, NSData * _Nonnull p);
bool MTCheckIsSafePrime(id<EncryptionProvider> _Nonnull provider, NSData * _Nonnull numberBytes, id<MTKeychain> _Nonnull keychain);
bool MTCheckIsSafeGAOrB(id<EncryptionProvider> _Nonnull provider, NSData * _Nonnull gAOrB, NSData * _Nonnull p);
bool MTCheckMod(id<EncryptionProvider> _Nonnull provider, NSData * _Nonnull numberBytes, unsigned int g, id<MTKeychain> _Nonnull keychain);
    
@interface MTAesCtr : NSObject

- (instancetype _Nonnull)initWithKey:(const void * _Nonnull)key keyLength:(int)keyLength iv:(const void * _Nonnull)iv decrypt:(bool)decrypt;
- (instancetype _Nonnull)initWithKey:(const void * _Nonnull)key keyLength:(int)keyLength iv:(const void * _Nonnull)iv ecount:(void * _Nonnull)ecount num:(uint32_t)num;

- (uint32_t)num;
- (void * _Nonnull)ecount;
- (void)getIv:(void * _Nonnull)iv;

- (void)encryptIn:(const unsigned char * _Nonnull)in out:(unsigned char * _Nonnull)out len:(size_t)len;

@end
    
uint64_t MTRsaFingerprint(id<EncryptionProvider> _Nonnull provider, NSString * _Nonnull key);
    
NSData * _Nullable MTRsaEncryptPKCS1OAEP(id<EncryptionProvider> _Nonnull provider, NSString * _Nonnull key, NSData * _Nonnull data);
    
@interface MTBackupDatacenterAddress : NSObject

@property (nonatomic, readonly) int32_t datacenterId;
@property (nonatomic, strong, readonly) NSString * _Nonnull ip;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, strong, readonly) NSData * _Nullable secret;

@end

@interface MTBackupDatacenterData : NSObject

@property (nonatomic, readonly) int32_t timestamp;
@property (nonatomic, readonly) int32_t expirationDate;
@property (nonatomic, strong, readonly) NSArray<MTBackupDatacenterAddress *> * _Nonnull addressList;

@end

MTBackupDatacenterData * _Nullable MTIPDataDecode(id<EncryptionProvider> _Nonnull provider, NSData * _Nonnull data, NSString * _Nonnull phoneNumber);
    
NSData * _Nullable MTPBKDF2(NSData * _Nonnull data, NSData * _Nonnull salt, int rounds);

#ifdef __cplusplus
}
#endif

#endif
