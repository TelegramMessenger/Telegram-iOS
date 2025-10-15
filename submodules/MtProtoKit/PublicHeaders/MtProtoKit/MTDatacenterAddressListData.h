#import <Foundation/Foundation.h>

@interface MTDatacenterAddressListData : NSObject

@property (nonatomic, strong, readonly) NSDictionary<NSNumber *, NSArray *> *addressList;

- (instancetype)initWithAddressList:(NSDictionary<NSNumber *, NSArray *> *)addressList;

@end
