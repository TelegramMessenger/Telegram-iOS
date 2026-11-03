#import <TelegramApiObjC/TLObject.h>
#import "TLObjectInternal.h"

#include <dispatch/dispatch.h>
#include <os/lock.h>
#include <stdlib.h>

#if __has_feature(objc_arc)
#error "TelegramApiObjC implements reference counting itself and must be compiled without ARC"
#endif

NS_ASSUME_NONNULL_BEGIN

enum {
    TLObjectFlagDeallocating = 1u << 0,
    TLObjectFlagImmortal = 1u << 1,
};

static int64_t TLObjectLiveCounter = 0;
static os_unfair_lock TLObjectRuntimeLock = OS_UNFAIR_LOCK_INIT;

static BOOL TLObjectIsKindOf(Class _Nullable cls, Class target) {
    for (Class current = cls; current != Nil; current = class_getSuperclass(current)) {
        if (current == target) {
            return YES;
        }
    }
    return NO;
}

@implementation TLObject

+ (void)initialize {
}

+ (Class)class {
    return self;
}

+ (id)self {
    return self;
}

+ (nullable Class)superclass {
    return class_getSuperclass(self);
}

+ (BOOL)isSubclassOfClass:(Class)cls {
    return TLObjectIsKindOf(self, cls);
}

+ (BOOL)respondsToSelector:(SEL)selector {
    return class_respondsToSelector(object_getClass(self), selector);
}

+ (BOOL)instancesRespondToSelector:(SEL)selector {
    return class_respondsToSelector(self, selector);
}

+ (nullable id)methodSignatureForSelector:(SEL)selector {
    return nil;
}

+ (void)doesNotRecognizeSelector:(SEL)selector {
    [NSException raise:NSInvalidArgumentException format:@"+[%s %s]: unrecognized selector", class_getName(self), sel_getName(selector)];
}

- (const TLConstructorInfo *)tl_constructorInfo {
    return _tl_info;
}

- (uint16_t)tl_typeIndex {
    return _tl_info->typeIndex;
}

- (uint16_t)tl_caseIndex {
    return _tl_info->caseIndex;
}

- (id)self {
    return self;
}

- (Class)class {
    return object_getClass(self);
}

- (nullable Class)superclass {
    return class_getSuperclass(object_getClass(self));
}

- (BOOL)isKindOfClass:(Class)cls {
    return TLObjectIsKindOf(object_getClass(self), cls);
}

- (BOOL)isMemberOfClass:(Class)cls {
    return object_getClass(self) == cls;
}

- (BOOL)respondsToSelector:(SEL)selector {
    return class_respondsToSelector(object_getClass(self), selector);
}

- (BOOL)conformsToProtocol:(Protocol *)protocol {
    return class_conformsToProtocol(object_getClass(self), protocol);
}

- (BOOL)isProxy {
    return NO;
}

- (BOOL)isEqual:(nullable id)other {
    return self == other;
}

- (NSUInteger)hash {
    return (NSUInteger)(uintptr_t)self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%s: %p>", class_getName(object_getClass(self)), self];
}

- (NSString *)debugDescription {
    return [self description];
}

- (struct _NSZone *_Nullable)zone {
    return NULL;
}

- (nullable id)methodSignatureForSelector:(SEL)selector {
    return nil;
}

- (void)doesNotRecognizeSelector:(SEL)selector {
    [NSException raise:NSInvalidArgumentException format:@"-[%s %s]: unrecognized selector", class_getName(object_getClass(self)), sel_getName(selector)];
}

- (instancetype)retain {
    if ((_tl_flags & TLObjectFlagImmortal) == 0) {
        __atomic_fetch_add(&_tl_refcount, 1, __ATOMIC_RELAXED);
    }
    return self;
}

- (oneway void)release {
    if ((_tl_flags & TLObjectFlagImmortal) != 0) {
        return;
    }
    if (__atomic_fetch_sub(&_tl_refcount, 1, __ATOMIC_ACQ_REL) == 1) {
        __atomic_fetch_or(&_tl_flags, TLObjectFlagDeallocating, __ATOMIC_RELAXED);
        [self dealloc];
    }
}

// CFAutorelease would send -autorelease back to us and recurse.
- (instancetype)autorelease {
    [NSAutoreleasePool addObject:self];
    return self;
}

- (NSUInteger)retainCount {
    if ((_tl_flags & TLObjectFlagImmortal) != 0) {
        return NSUIntegerMax;
    }
    return __atomic_load_n(&_tl_refcount, __ATOMIC_RELAXED);
}

- (BOOL)_tryRetain {
    if ((_tl_flags & TLObjectFlagImmortal) != 0) {
        return YES;
    }
    uint32_t count = __atomic_load_n(&_tl_refcount, __ATOMIC_RELAXED);
    while (count != 0) {
        if (__atomic_compare_exchange_n(&_tl_refcount, &count, count + 1, true, __ATOMIC_ACQ_REL, __ATOMIC_RELAXED)) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)_isDeallocating {
    return (__atomic_load_n(&_tl_flags, __ATOMIC_RELAXED) & TLObjectFlagDeallocating) != 0;
}

- (BOOL)allowsWeakReference {
    return ![self _isDeallocating];
}

- (BOOL)retainWeakReference {
    return [self _tryRetain];
}

- (void)dealloc {
    const TLConstructorInfo *info = _tl_info;
    if (info != NULL && info->fieldCount != 0) {
        char *base = (char *)self;
        for (uint16_t i = 0; i < info->fieldCount; i++) {
            switch (info->fields[i].kind) {
                case TLFieldKindInt32:
                case TLFieldKindInt64:
                case TLFieldKindInt256:
                case TLFieldKindDouble:
                    break;
                case TLFieldKindString:
                case TLFieldKindBytes:
                case TLFieldKindObject:
                case TLFieldKindVector: {
                    id value = *(id *)(base + info->fields[i].offset);
                    [value release];
                    break;
                }
            }
        }
    }
    objc_destructInstance(self);
    __atomic_fetch_sub(&TLObjectLiveCounter, 1, __ATOMIC_RELAXED);
    free(self);
}

@end

int64_t TLObjectLiveCount(void) {
    return __atomic_load_n(&TLObjectLiveCounter, __ATOMIC_RELAXED);
}

TLObject *TLObjectSingleton(const TLConstructorInfo *info) {
    TLObject *existing = (TLObject *)__atomic_load_n(&info->state->singleton, __ATOMIC_ACQUIRE);
    if (existing != nil) {
        return existing;
    }
    os_unfair_lock_lock(&TLObjectRuntimeLock);
    TLObject *object = (TLObject *)info->state->singleton;
    if (object == nil) {
        object = TLObjectAllocate(info);
        object->_tl_flags |= TLObjectFlagImmortal;
        __atomic_fetch_sub(&TLObjectLiveCounter, 1, __ATOMIC_RELAXED);
        __atomic_store_n(&info->state->singleton, (void *)object, __ATOMIC_RELEASE);
    }
    os_unfair_lock_unlock(&TLObjectRuntimeLock);
    return object;
}

void TLObjectDescribe(TLObject *object, void *_Nullable context, TLFieldSink sink) {
    const TLConstructorInfo *info = object->_tl_info;
    if (info->fieldCount == 0) {
        return;
    }
    const char *base = (const char *)object;
    uint64_t present = info->presentOffset >= 0 ? *(const uint64_t *)(base + info->presentOffset) : 0;
    for (uint16_t i = 0; i < info->fieldCount; i++) {
        const TLFieldInfo *field = &info->fields[i];
        const void *slot = base + info->fields[i].offset;
        switch (field->kind) {
            case TLFieldKindInt32:
            case TLFieldKindInt64:
            case TLFieldKindInt256:
            case TLFieldKindDouble:
                if (field->isOptional && (present & (1ull << field->presenceBit)) == 0) {
                    sink(context, field, NULL, nil);
                } else {
                    sink(context, field, slot, nil);
                }
                break;
            case TLFieldKindString:
            case TLFieldKindBytes:
            case TLFieldKindObject:
            case TLFieldKindVector:
                sink(context, field, NULL, *(id const *)slot);
                break;
        }
    }
}

TLObject *TLObjectAllocate(const TLConstructorInfo *info) {
    static size_t headerSize;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        headerSize = class_getInstanceSize([TLObject class]);
    });
    TLObject *object = class_createInstance([TLObject class], info->instanceSize - headerSize);
    object->_tl_refcount = 1;
    object->_tl_info = info;
    __atomic_fetch_add(&TLObjectLiveCounter, 1, __ATOMIC_RELAXED);
    return object;
}

TLObject *TLObjectCreate(const TLConstructorInfo *info) {
    return TLObjectAllocate(info);
}

NS_ASSUME_NONNULL_END
