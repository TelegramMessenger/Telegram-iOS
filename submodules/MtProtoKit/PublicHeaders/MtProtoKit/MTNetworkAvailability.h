

#import <Foundation/Foundation.h>

@class MTNetworkAvailability;

@protocol MTNetworkAvailabilityDelegate <NSObject>

@optional

- (void)networkAvailabilityChanged:(MTNetworkAvailability *)networkAvailability networkIsAvailable:(bool)networkIsAvailable;

@end

@interface MTNetworkAvailability : NSObject

@property (nonatomic, weak) id<MTNetworkAvailabilityDelegate> delegate;

- (instancetype)initWithDelegate:(id<MTNetworkAvailabilityDelegate>)delegate;

@end
