#import <MtProtoKit/MTDatacenterAddressSet.h>

#import <MtProtoKit/MTDatacenterAddress.h>

@implementation MTDatacenterAddressSet

- (instancetype)initWithAddressList:(NSArray *)addressList
{
    self = [super init];
    if (self != nil)
    {
        _addressList = addressList;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _addressList = [aDecoder decodeObjectForKey:@"addressList"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_addressList forKey:@"addressList"];
}

- (BOOL)isEqual:(MTDatacenterAddressSet *)another
{
    if (![another isKindOfClass:[MTDatacenterAddressSet class]])
        return false;
    
    if (_addressList.count != another.addressList.count)
        return false;
    
    for (NSUInteger i = 0; i < _addressList.count; i++)
    {
        if (![_addressList[i] isEqual:another.addressList[i]])
            return false;
    }
    
    return true;
}

- (NSString *)description
{
    NSMutableString *string = [[NSMutableString alloc] init];
    [string appendString:@"["];
    for (MTDatacenterAddress *address in _addressList)
    {
        if (string.length != 1)
            [string appendString:@", "];
        [string appendString:[address description]];
    }
    [string appendString:@"]"];
    
    return string;
}

- (MTDatacenterAddress *)firstAddress
{
    return _addressList.count == 0 ? nil : _addressList[0];
}

@end
