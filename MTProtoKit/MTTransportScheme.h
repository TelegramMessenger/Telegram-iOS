

#import <Foundation/Foundation.h>

@class MTContext;
@class MTTransport;
@class MTDatacenterAddress;
@protocol MTTransportDelegate;
@class MTNetworkUsageCalculationInfo;

@interface MTTransportScheme : NSObject <NSCoding>

@property (nonatomic, strong, readonly) Class transportClass;
@property (nonatomic, strong, readonly) MTDatacenterAddress *address;
@property (nonatomic, readonly) bool media;

- (instancetype)initWithTransportClass:(Class)transportClass address:(MTDatacenterAddress *)address media:(bool)media;

- (BOOL)isEqualToScheme:(MTTransportScheme *)other;
- (BOOL)isOptimal;
- (NSComparisonResult)compareToScheme:(MTTransportScheme *)other;

@end
