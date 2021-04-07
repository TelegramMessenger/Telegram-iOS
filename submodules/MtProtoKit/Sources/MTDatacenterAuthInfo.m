#import <MtProtoKit/MTDatacenterAuthInfo.h>
#import <MtProtoKit/MTDatacenterSaltInfo.h>

@implementation MTDatacenterAuthKey

- (instancetype)initWithAuthKey:(NSData *)authKey authKeyId:(int64_t)authKeyId notBound:(bool)notBound {
    self = [super init];
    if (self != nil) {
        _authKey = authKey;
        _authKeyId = authKeyId;
        _notBound = notBound;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithAuthKey:[aDecoder decodeObjectForKey:@"key"] authKeyId:[aDecoder decodeInt64ForKey:@"keyId"] notBound:[aDecoder decodeBoolForKey:@"notBound"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_authKey forKey:@"key"];
    [aCoder encodeInt64:_authKeyId forKey:@"keyId"];
    [aCoder encodeBool:_notBound forKey:@"notBound"];
}

@end

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

- (MTDatacenterAuthInfo *)mergeSaltSet:(NSArray *)updatedSaltSet forTimestamp:(NSTimeInterval)timestamp
{
    int64_t referenceMessageId = (int64_t)(timestamp * 4294967296);
    
    NSMutableArray *mergedSaltSet = [[NSMutableArray alloc] init];
    
    for (MTDatacenterSaltInfo *saltInfo in _saltSet)
    {
        if ([saltInfo isValidFutureSaltForMessageId:referenceMessageId])
            [mergedSaltSet addObject:saltInfo];
    }
    
    for (MTDatacenterSaltInfo *saltInfo in updatedSaltSet)
    {
        bool alreadExists = false;
        for (MTDatacenterSaltInfo *existingSaltInfo in mergedSaltSet)
        {
            if (existingSaltInfo.firstValidMessageId == saltInfo.firstValidMessageId)
            {
                alreadExists = true;
                break;
            }
        }
        
        if (!alreadExists)
        {
            if ([saltInfo isValidFutureSaltForMessageId:referenceMessageId])
                [mergedSaltSet addObject:saltInfo];
        }
    }
    
    return [[MTDatacenterAuthInfo alloc] initWithAuthKey:_authKey authKeyId:_authKeyId saltSet:mergedSaltSet authKeyAttributes:_authKeyAttributes];
}

- (MTDatacenterAuthInfo *)withUpdatedAuthKeyAttributes:(NSDictionary *)authKeyAttributes {
    return [[MTDatacenterAuthInfo alloc] initWithAuthKey:_authKey authKeyId:_authKeyId saltSet:_saltSet authKeyAttributes:authKeyAttributes];
}

- (MTDatacenterAuthKey *)persistentAuthKey {
    return [[MTDatacenterAuthKey alloc] initWithAuthKey:_authKey authKeyId:_authKeyId notBound:false];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"MTDatacenterAuthInfo authKeyId:%" PRId64 " authKey:%lu", _authKeyId, (unsigned long)_authKey.length];
}

@end
