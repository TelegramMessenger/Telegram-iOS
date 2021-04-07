#import <Foundation/Foundation.h>

@class MTSignal;

@interface TGShareLocationResult : NSObject

@property (nonatomic, readonly) double latitude;
@property (nonatomic, readonly) double longitude;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *address;
@property (nonatomic, readonly) NSString *provider;
@property (nonatomic, readonly) NSString *venueId;
@property (nonatomic, readonly) NSString *venueType;

- (instancetype)initWithLatitude:(double)latitude longitude:(double)longitude title:(NSString *)title address:(NSString *)address provider:(NSString *)provider venueId:(NSString *)venueId venueType:(NSString *)venueType;

@end

@interface TGShareLocationSignals : NSObject

+ (MTSignal *)locationMessageContentForURL:(NSURL *)url;
+ (bool)isLocationURL:(NSURL *)url;

@end
