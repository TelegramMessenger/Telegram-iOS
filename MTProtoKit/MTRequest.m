/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTRequest.h"

#import "MTRpcError.h"

#import <libkern/OSAtomic.h>

@interface MTRequestInternalId : NSObject <NSCopying>
{
    NSUInteger _value;
}

@end

@implementation MTRequestInternalId

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        static int32_t nextValue = 1;
        _value = OSAtomicIncrement32(&nextValue);
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[MTRequestInternalId class]] && ((MTRequestInternalId *)object)->_value == _value;
}

- (NSUInteger)hash
{
    return _value;
}

- (instancetype)copyWithZone:(NSZone *)__unused zone
{
    MTRequestInternalId *another = [[MTRequestInternalId alloc] init];
    if (another != nil)
        another->_value = _value;
    return another;
}

@end

@implementation MTRequest

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _internalId = [[MTRequestInternalId alloc] init];
        _dependsOnPasswordEntry = true;
    }
    return self;
}

- (void)setPayload:(NSData *)payload metadata:(id)metadata responseParser:(id (^)(NSData *))responseParser
{
    _payload = payload;
    _metadata = metadata;
    _responseParser = [responseParser copy];
}

@end
