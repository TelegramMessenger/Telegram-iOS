/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTDatacenterAddressSet.h>

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

- (MTDatacenterAddress *)firstAddress
{
    return _addressList.count == 0 ? nil : _addressList[0];
}

@end
