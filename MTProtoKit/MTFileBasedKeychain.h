#import <Foundation/Foundation.h>

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTKeychain.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTKeychain.h>
#else
#   import <MTProtoKit/MTKeychain.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface MTFileBasedKeychain : NSObject <MTKeychain>

+ (instancetype)unencryptedKeychainWithName:(NSString * _Nullable)name documentsPath:(NSString *)documentsPath;
+ (instancetype)keychainWithName:(NSString * _Nullable)name documentsPath:(NSString * _Nullable)documentsPath;

- (NSDictionary<NSString *, id> *)contentsForGroup:(NSString *)group;

@end

NS_ASSUME_NONNULL_END
