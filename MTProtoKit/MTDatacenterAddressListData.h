#import <Foundation/Foundation.h>

@interface MTDatacenterAddressListData : NSObject

@property (nonatomic, strong, readonly) NSArray *addressList;

- (instancetype)initWithAddressList:(NSArray *)addressList;

@end
