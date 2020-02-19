#import <Foundation/Foundation.h>

#import <MtProtoKit/MTEncryption.h>


void MyAesIgeEncrypt(const void *inBytes, int length, void *outBytes, const void *key, int keyLength, void *iv);
void MyAesIgeDecrypt(const void *inBytes, int length, void *outBytes, const void *key, int keyLength, void *iv);
void MyAesCbcDecrypt(const void *inBytes, int length, void *outBytes, const void *key, int keyLength, void *iv);
