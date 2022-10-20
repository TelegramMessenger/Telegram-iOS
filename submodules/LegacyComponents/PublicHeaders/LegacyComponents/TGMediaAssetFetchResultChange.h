#import <LegacyComponents/TGMediaAssetFetchResult.h>

@class PHFetchResultChangeDetails;

@interface TGMediaAssetFetchResultChange : NSObject

@property (nonatomic, readonly) TGMediaAssetFetchResult *fetchResultBeforeChanges;
@property (nonatomic, readonly) TGMediaAssetFetchResult *fetchResultAfterChanges;

@property (nonatomic, readonly) bool hasIncrementalChanges;

@property (nonatomic, readonly) NSIndexSet *removedIndexes;
@property (nonatomic, readonly) NSIndexSet *insertedIndexes;
@property (nonatomic, readonly) NSIndexSet *updatedIndexes;

@property (nonatomic, readonly) bool hasMoves;
- (void)enumerateMovesWithBlock:(void(^)(NSUInteger fromIndex, NSUInteger toIndex))handler;

+ (instancetype)changeWithPHFetchResultChangeDetails:(PHFetchResultChangeDetails *)changeDetails reversed:(bool)reversed;

@end
