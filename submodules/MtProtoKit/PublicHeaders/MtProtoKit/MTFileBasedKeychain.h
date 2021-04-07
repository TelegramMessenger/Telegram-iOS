#import <Foundation/Foundation.h>

#import <MtProtoKit/MTKeychain.h>


NS_ASSUME_NONNULL_BEGIN

@interface MTFileBasedKeychain : NSObject <MTKeychain>

+ (instancetype)unencryptedKeychainWithName:(NSString * _Nullable)name documentsPath:(NSString *)documentsPath;
+ (instancetype)keychainWithName:(NSString * _Nullable)name documentsPath:(NSString * _Nullable)documentsPath;

- (NSDictionary<NSString *, id> *)contentsForGroup:(NSString *)group;

@end

NS_ASSUME_NONNULL_END
