#import <Foundation/Foundation.h>

@interface SAtomic : NSObject

- (instancetype _Nonnull)initWithValue:(id _Nullable)value;
- (instancetype _Nonnull)initWithValue:(id _Nullable)value recursive:(bool)recursive;
- (id _Nullable)swap:(id _Nullable)newValue;
- (id _Nullable)value;
- (id _Nullable)modify:(id _Nullable (^ _Nonnull)(id _Nullable))f;
- (id _Nullable)with:(id _Nullable (^ _Nonnull)(id _Nullable))f;

@end
