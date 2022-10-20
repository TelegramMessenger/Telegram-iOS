#import <Foundation/Foundation.h>

@interface SAtomic : NSObject

- (instancetype)initWithValue:(id)value;
- (instancetype)initWithValue:(id)value recursive:(bool)recursive;
- (id)swap:(id)newValue;
- (id)value;
- (id)modify:(id (^)(id))f;
- (id)with:(id (^)(id))f;

@end
