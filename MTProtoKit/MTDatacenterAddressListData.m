#import "MTDatacenterAddressListData.h"

@implementation MTDatacenterAddressListData

- (instancetype)initWithAddressList:(NSArray *)addressList
{
    self = [super init];
    if (self != nil)
    {
        _addressList = addressList;
    }
    return self;
}

@end
