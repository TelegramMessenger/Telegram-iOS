

#import <Foundation/Foundation.h>

@class MTContext;
@class MTDiscoverDatacenterAddressAction;

@protocol MTDiscoverDatacenterAddressActionDelegate <NSObject>

- (void)discoverDatacenterAddressActionCompleted:(MTDiscoverDatacenterAddressAction *)action;

@end

@interface MTDiscoverDatacenterAddressAction : NSObject

@property (nonatomic, weak) id<MTDiscoverDatacenterAddressActionDelegate> delegate;

- (void)execute:(MTContext *)context datacenterId:(NSInteger)datacenterId;
- (void)cancel;

@end
