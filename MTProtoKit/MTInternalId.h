/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

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
