#import "RuntimeUtils.h"

#import <objc/runtime.h>

@interface CALayer ()

- (unsigned int)contextId;
- (void)setContextId:(unsigned int)contextId;

@end

@implementation RuntimeUtils

+ (CALayer * _Nonnull)makeLayerHostCopy:(CALayer * _Nonnull)another {
    CALayer *result = [[NSClassFromString(@"CALayerHost") alloc] init];
    [result setContextId:[another contextId]];
    return result;
}

+ (void)swizzleInstanceMethodOfClass:(Class)targetClass currentSelector:(SEL)currentSelector newSelector:(SEL)newSelector {
    Method origMethod = nil, newMethod = nil;
    
    origMethod = class_getInstanceMethod(targetClass, currentSelector);
    newMethod = class_getInstanceMethod(targetClass, newSelector);
    if ((origMethod != nil) && (newMethod != nil)) {
        if (class_addMethod(targetClass, currentSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
            class_replaceMethod(targetClass, newSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
        } else {
            method_exchangeImplementations(origMethod, newMethod);
        }
    }
}

+ (void)swizzleInstanceMethodOfClass:(Class)targetClass currentSelector:(SEL)currentSelector withAnotherClass:(Class)anotherClass newSelector:(SEL)newSelector {
    Method origMethod = nil, newMethod = nil;
    
    origMethod = class_getInstanceMethod(targetClass, currentSelector);
    newMethod = class_getInstanceMethod(anotherClass, newSelector);
    if ((origMethod != nil) && (newMethod != nil)) {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

+ (void)swizzleClassMethodOfClass:(Class)targetClass currentSelector:(SEL)currentSelector newSelector:(SEL)newSelector {
    Method origMethod = nil, newMethod = nil;
    
    origMethod = class_getClassMethod(targetClass, currentSelector);
    newMethod = class_getClassMethod(targetClass, newSelector);
    
    targetClass = object_getClass((id)targetClass);
    
    if ((origMethod != nil) && (newMethod != nil)) {
        if (class_addMethod(targetClass, currentSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
            class_replaceMethod(targetClass, newSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
        } else {
            method_exchangeImplementations(origMethod, newMethod);
        }
    }
}

@end

@implementation NSObject (AssociatedObject)

- (void)setAssociatedObject:(id)object forKey:(void const *)key
{
    [self setAssociatedObject:object forKey:key associationPolicy:NSObjectAssociationPolicyRetain];
}

- (void)setAssociatedObject:(id)object forKey:(void const *)key associationPolicy:(NSObjectAssociationPolicy)associationPolicy
{
    int policy = 0;
    switch (associationPolicy)
    {
        case NSObjectAssociationPolicyRetain:
            policy = OBJC_ASSOCIATION_RETAIN_NONATOMIC;
            break;
        case NSObjectAssociationPolicyCopy:
            policy = OBJC_ASSOCIATION_COPY_NONATOMIC;
            break;
        default:
            policy = OBJC_ASSOCIATION_RETAIN_NONATOMIC;
            break;
    }
    objc_setAssociatedObject(self, key, object, policy);
}

- (id)associatedObjectForKey:(void const *)key
{
    return objc_getAssociatedObject(self, key);
}

- (bool)checkObjectIsKindOfClass:(Class)targetClass {
    return [self isKindOfClass:targetClass];
}

- (void)setClass:(Class)newClass {
    object_setClass(self, newClass);
}

- (NSNumber * _Nullable)floatValueForKeyPath:(NSString * _Nonnull)keyPath {
    id value = [self valueForKeyPath:keyPath];
    if (value != nil) {
        if ([value respondsToSelector:@selector(floatValue)]) {
            return @([value floatValue]);
        } else {
            return nil;
        }
    } else {
        return nil;
    }
}

+ (NSArray<NSString *> * _Nonnull)getIvarList:(Class _Nonnull)classValue {
    NSMutableArray<NSString *> *result = [[NSMutableArray alloc] init];

    unsigned int varCount;

    Ivar *vars = class_copyIvarList(classValue, &varCount);

    for (int i = 0; i < varCount; i++) {
        Ivar var = vars[i];

        const char* name = ivar_getName(var);
        const char* typeEncoding = ivar_getTypeEncoding(var);

        [result addObject:[NSString stringWithFormat:@"%s: %s", name, typeEncoding]];
    }

    free(vars);

    return result;
}

- (id _Nullable)getIvarValue:(NSString * _Nonnull)name {
    Ivar ivar = class_getInstanceVariable([self class], [name UTF8String]);
    if (!ivar){
       return nil;
    }
    id value = object_getIvar(self, ivar);
    return value;
}

@end

SEL _Nonnull makeSelectorFromString(NSString * _Nonnull string) {
    return NSSelectorFromString(string);
}
