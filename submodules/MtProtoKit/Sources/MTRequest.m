#import <MtProtoKit/MTRequest.h>

#import <MtProtoKit/MTRpcError.h>

#import <os/lock.h>
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        _value = OSAtomicIncrement32(&nextValue);
#pragma clang diagnostic pop
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

- (void)setPayload:(NSData *)payload metadata:(id)metadata shortMetadata:(id)shortMetadata responseParser:(id (^)(NSData *))responseParser
{
    _payload = payload;
    _metadata = metadata;
    _shortMetadata = shortMetadata;
    _responseParser = [responseParser copy];
}

@end
