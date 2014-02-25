/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTDatacenterAuthInfo.h>

#import <MTProtoKit/MTDatacenterSaltInfo.h>

@implementation MTDatacenterAuthInfo

- (instancetype)initWithAuthKey:(NSData *)authKey authKeyId:(int64_t)authKeyId saltSet:(NSArray *)saltSet authKeyAttributes:(NSDictionary *)authKeyAttributes
{
    self = [super init];
    if (self != nil)
    {
        _authKey = authKey;
        _authKeyId = authKeyId;
        _saltSet = saltSet;
        _authKeyAttributes = authKeyAttributes;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _authKey = [aDecoder decodeObjectForKey:@"authKey"];
        _authKeyId = [aDecoder decodeInt64ForKey:@"authKeyId"];
        _saltSet = [aDecoder decodeObjectForKey:@"saltSet"];
        _authKeyAttributes = [aDecoder decodeObjectForKey:@"authKeyAttributes"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_authKey forKey:@"authKey"];
    [aCoder encodeInt64:_authKeyId forKey:@"authKeyId"];
    [aCoder encodeObject:_saltSet forKey:@"saltSet"];
    [aCoder encodeObject:_authKeyAttributes forKey:@"authKeyAttributes"];
}

- (int64_t)authSaltForMessageId:(int64_t)messageId
{
    int64_t bestSalt = 0;
    int64_t bestValidMessageCount = 0;
    
    for (MTDatacenterSaltInfo *saltInfo in _saltSet)
    {
        int64_t currentValidMessageCount = [saltInfo validMessageCountAfterId:messageId];
        if (currentValidMessageCount != 0 && currentValidMessageCount > bestValidMessageCount)
            bestSalt = saltInfo.salt;
    }
    
    return bestSalt;
}

@end
