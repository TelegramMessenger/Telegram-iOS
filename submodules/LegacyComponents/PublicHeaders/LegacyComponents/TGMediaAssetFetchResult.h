#import <Foundation/Foundation.h>

@class PHFetchResult;
@class ALAsset;

@class TGMediaAsset;

@interface TGMediaAssetFetchResult : NSObject

@property (nonatomic, readonly) NSUInteger count;

- (instancetype)initWithPHFetchResult:(PHFetchResult *)fetchResult reversed:(bool)reversed;

- (TGMediaAsset *)assetAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfAsset:(TGMediaAsset *)asset;

@end
