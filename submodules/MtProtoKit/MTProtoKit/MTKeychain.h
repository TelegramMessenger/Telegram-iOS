

#import <Foundation/Foundation.h>

@protocol MTKeychain <NSObject>

- (void)setObject:(id)object forKey:(NSString *)aKey group:(NSString *)group;
- (id)objectForKey:(NSString *)aKey group:(NSString *)group;
- (void)removeObjectForKey:(NSString *)aKey group:(NSString *)group;

- (void)dropGroup:(NSString *)group;

@end
