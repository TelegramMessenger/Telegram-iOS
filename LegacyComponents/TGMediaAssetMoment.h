#import <Photos/Photos.h>

@class TGMediaAssetFetchResult;

@interface TGMediaAssetMoment : NSObject

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSDate *startDate;
@property (nonatomic, readonly) NSDate *endDate;
@property (nonatomic, readonly) CLLocation *location;
@property (nonatomic, readonly) NSArray *locationNames;
@property (nonatomic, readonly) NSUInteger assetCount;

@property (nonatomic, readonly) TGMediaAssetFetchResult *fetchResult;

- (instancetype)initWithPHAssetCollection:(PHAssetCollection *)collection;

@end
