#import <Foundation/Foundation.h>

void MyAesIgeEncrypt(const void *inBytes, int length, void *outBytes, const void *key, int keyLength, void *iv);
void MyAesIgeDecrypt(const void *inBytes, int length, void *outBytes, const void *key, int keyLength, void *iv);

@interface MTAesCtr : NSObject

- (instancetype)initWithKey:(const void *)key keyLength:(int)keyLength iv:(const void *)iv decrypt:(bool)decrypt;
- (void)encryptIn:(const unsigned char *)in out:(unsigned char *)out len:(size_t)len;

@end
