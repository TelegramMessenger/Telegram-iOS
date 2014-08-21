/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTMessageEncryptionKey : NSObject

@property (nonatomic, strong, readonly) NSData *key;
@property (nonatomic, strong, readonly) NSData *iv;

+ (instancetype)messageEncryptionKeyForAuthKey:(NSData *)authKey messageKey:(NSData *)messageKey toClient:(bool)toClient;
- (instancetype)initWithKey:(NSData *)key iv:(NSData *)iv;

@end
