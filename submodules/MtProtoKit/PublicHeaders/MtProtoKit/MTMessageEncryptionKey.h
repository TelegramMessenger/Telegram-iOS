

#import <Foundation/Foundation.h>

@interface MTMessageEncryptionKey : NSObject

@property (nonatomic, strong, readonly) NSData *key;
@property (nonatomic, strong, readonly) NSData *iv;

+ (instancetype)messageEncryptionKeyForAuthKey:(NSData *)authKey messageKey:(NSData *)messageKey toClient:(bool)toClient;
+ (instancetype)messageEncryptionKeyV2ForAuthKey:(NSData *)authKey messageKey:(NSData *)messageKey toClient:(bool)toClient;

- (instancetype)initWithKey:(NSData *)key iv:(NSData *)iv;

@end
