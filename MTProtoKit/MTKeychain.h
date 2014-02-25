/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTKeychain : NSObject

+ (instancetype)unencryptedKeychainWithName:(NSString *)name;
+ (instancetype)keychainWithName:(NSString *)name;

- (void)setObject:(id)object forKey:(id<NSCopying>)aKey group:(NSString *)group;
- (id)objectForKey:(id<NSCopying>)aKey group:(NSString *)group;
- (void)removeObjectForKey:(id<NSCopying>)aKey group:(NSString *)group;

@end
