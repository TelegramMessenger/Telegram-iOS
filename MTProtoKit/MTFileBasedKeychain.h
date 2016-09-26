#import <Foundation/Foundation.h>

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTKeychain.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTKeychain.h>
#else
#   import <MTProtoKit/MTKeychain.h>
#endif

@interface MTFileBasedKeychain : NSObject <MTKeychain>

+ (instancetype)unencryptedKeychainWithName:(NSString *)name documentsPath:(NSString *)documentsPath;
+ (instancetype)keychainWithName:(NSString *)name documentsPath:(NSString *)documentsPath;

@end
