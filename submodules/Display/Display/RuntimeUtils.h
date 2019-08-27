#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum {
    NSObjectAssociationPolicyRetain = 0,
    NSObjectAssociationPolicyCopy = 1
} NSObjectAssociationPolicy;

@interface RuntimeUtils : NSObject

+ (void)swizzleInstanceMethodOfClass:(Class)targetClass currentSelector:(SEL)currentSelector newSelector:(SEL)newSelector;
+ (void)swizzleInstanceMethodOfClass:(Class)targetClass currentSelector:(SEL)currentSelector withAnotherClass:(Class)anotherClass newSelector:(SEL)newSelector;
+ (void)swizzleClassMethodOfClass:(Class)targetClass currentSelector:(SEL)currentSelector newSelector:(SEL)newSelector;
+ (CALayer * _Nonnull)makeLayerHostCopy:(CALayer * _Nonnull)another;

@end

@interface NSObject (AssociatedObject)

- (void)setAssociatedObject:(id)object forKey:(void const *)key;
- (void)setAssociatedObject:(id)object forKey:(void const *)key associationPolicy:(NSObjectAssociationPolicy)associationPolicy;
- (id)associatedObjectForKey:(void const *)key;
- (bool)checkObjectIsKindOfClass:(Class)targetClass;
- (void)setClass:(Class)newClass;

@end
