

#import <Foundation/Foundation.h>

@class MTContext;
@class MTTransport;
@class MTDatacenterAddress;
@protocol MTTransportDelegate;
@class MTNetworkUsageCalculationInfo;

@interface MTTransportScheme : NSObject <NSCoding>

@property (nonatomic, strong, readonly) Class _Nonnull transportClass;
@property (nonatomic, strong, readonly) MTDatacenterAddress * _Nonnull address;
@property (nonatomic, readonly) bool media;

- (instancetype _Nonnull)initWithTransportClass:(Class _Nonnull)transportClass address:(MTDatacenterAddress * _Nonnull)address media:(bool)media;

- (BOOL)isEqualToScheme:(MTTransportScheme * _Nonnull)other;
- (BOOL)isOptimal;
- (NSComparisonResult)compareToScheme:(MTTransportScheme * _Nonnull)other;

@end
