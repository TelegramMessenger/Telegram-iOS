

#ifndef MtProtoKit_MTInternalId_h
#define MtProtoKit_MTInternalId_h

#import <libkern/OSAtomic.h>

#define MTInternalId(name) MT##name##InternalId

#define MTInternalIdClass(name) \
@interface MT##name##InternalId : NSObject <NSCopying> \
{ \
    NSUInteger _value; \
} \
\
@end \
\
@implementation MT##name##InternalId \
\
- (instancetype)init \
{ \
    self = [super init]; \
    if (self != nil) \
    { \
        static int32_t nextValue = 1; \
        _value = OSAtomicIncrement32(&nextValue); \
    } \
    return self; \
} \
\
- (BOOL)isEqual:(id)object \
{ \
    return [object isKindOfClass:[MT##name##InternalId class]] && ((MT##name##InternalId *)object)->_value == _value; \
} \
\
- (NSUInteger)hash \
{ \
    return _value; \
} \
\
- (instancetype)copyWithZone:(NSZone *)__unused zone \
{ \
    MT##name##InternalId *another = [[MT##name##InternalId alloc] init]; \
    if (another != nil) \
        another->_value = _value; \
    return another; \
} \
\
@end

#endif
