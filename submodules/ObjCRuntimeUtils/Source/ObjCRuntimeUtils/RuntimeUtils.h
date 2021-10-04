#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum {
    NSObjectAssociationPolicyRetain = 0,
    NSObjectAssociationPolicyCopy = 1
} NSObjectAssociationPolicy;

@interface RuntimeUtils : NSObject

+ (void)swizzleInstanceMethodOfClass:(Class _Nonnull)targetClass currentSelector:(SEL _Nonnull)currentSelector newSelector:(SEL _Nonnull)newSelector;
+ (void)swizzleInstanceMethodOfClass:(Class _Nonnull)targetClass currentSelector:(SEL _Nonnull)currentSelector withAnotherClass:(Class _Nonnull)anotherClass newSelector:(SEL _Nonnull)newSelector;
+ (void)swizzleClassMethodOfClass:(Class _Nonnull)targetClass currentSelector:(SEL _Nonnull)currentSelector newSelector:(SEL _Nonnull)newSelector;
+ (CALayer * _Nonnull)makeLayerHostCopy:(CALayer * _Nonnull)another;

@end

@interface NSObject (AssociatedObject)

- (void)setAssociatedObject:(id _Nullable)object forKey:(void const * _Nonnull)key;
- (void)setAssociatedObject:(id _Nullable)object forKey:(void const * _Nonnull)key associationPolicy:(NSObjectAssociationPolicy)associationPolicy;
- (id _Nullable)associatedObjectForKey:(void const * _Nonnull)key;
- (bool)checkObjectIsKindOfClass:(Class _Nonnull)targetClass;
- (void)setClass:(Class _Nonnull)newClass;
+ (NSArray<NSString *> * _Nonnull)getIvarList:(Class _Nonnull)classValue;
- (id _Nullable)getIvarValue:(NSString * _Nonnull)name;

- (NSNumber * _Nullable)floatValueForKeyPath:(NSString * _Nonnull)keyPath;

@end

SEL _Nonnull makeSelectorFromString(NSString * _Nonnull string);
