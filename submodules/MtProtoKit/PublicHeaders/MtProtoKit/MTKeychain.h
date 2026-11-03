

#import <Foundation/Foundation.h>

@protocol MTKeychain <NSObject>

- (void)setObject:(id)object forKey:(NSString *)aKey group:(NSString *)group;
- (NSDictionary *)dictionaryForKey:(NSString *)aKey group:(NSString *)group;
- (NSNumber *)numberForKey:(NSString *)aKey group:(NSString *)group;
- (void)removeObjectForKey:(NSString *)aKey group:(NSString *)group;

@end

@interface MTDeprecated : NSObject

+ (id)unarchiveDeprecatedWithData:(NSData *)data;

@end
