#import <Foundation/Foundation.h>

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTEncryption.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTEncryption.h>
#else
#   import <MTProtoKit/MTEncryption.h>
#endif

void MyAesIgeEncrypt(const void *inBytes, int length, void *outBytes, const void *key, int keyLength, void *iv);
void MyAesIgeDecrypt(const void *inBytes, int length, void *outBytes, const void *key, int keyLength, void *iv);
