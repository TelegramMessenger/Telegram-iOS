#import <Foundation/Foundation.h>

#ifdef MtProtoKitDynamicFramework
#   import <MTProtoKitDynamic/MTKeychain.h>
#else
#   import <MTProtoKit/MTKeychain.h>
#endif

@interface MTFileBasedKeychain : NSObject <MTKeychain>

+ (instancetype)unencryptedKeychainWithName:(NSString *)name documentsPath:(NSString *)documentsPath;
+ (instancetype)keychainWithName:(NSString *)name documentsPath:(NSString *)documentsPath;

@end
