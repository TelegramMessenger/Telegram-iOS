#import "TGMediaAssetMomentList.h"
#import "TGMediaAssetFetchResult.h"

@interface TGMediaAssetMomentList ()
{
    NSArray *_list;
    
    NSArray *_latestAssets;
}
@end

@implementation TGMediaAssetMomentList

- (instancetype)initWithPHFetchResult:(PHFetchResult *)fetchResult
{
    self = [super init];
    if (self != nil)
    {
        NSMutableArray *moments = [[NSMutableArray alloc] init];
        [fetchResult enumerateObjectsUsingBlock:^(PHAssetCollection *collection, __unused NSUInteger idx, __unused BOOL *stop)
        {
            TGMediaAssetMoment *moment = [[TGMediaAssetMoment alloc] initWithPHAssetCollection:collection];
            [moments addObject:moment];
        }];
        
        _list = moments;
    }
    return self;
}

- (NSArray *)latestAssets
{
    if (_latestAssets == nil)
    {
        NSMutableArray *latestAssets = [[NSMutableArray alloc] init];
        
        [_list enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(TGMediaAssetMoment *moment, __unused NSUInteger idx, BOOL *stop)
        {
            TGMediaAssetFetchResult *result = moment.fetchResult;
            NSInteger assetsLeftToFill = MIN(3 - latestAssets.count, result.count);
            NSUInteger totalCount = result.count;
            
            for (NSUInteger i = 0; i < totalCount; i++)
            {
                NSInteger index = totalCount - i - 1;
                TGMediaAsset *pickerAsset = [result assetAtIndex:index];
                if (pickerAsset != nil)
                    [latestAssets addObject:pickerAsset];
            }
            
            if (assetsLeftToFill == 0)
                *stop = true;
        }];
        
        _latestAssets = latestAssets;
    }
    
    return _latestAssets;
}

- (NSUInteger)count
{
    return _list.count;
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx
{
    if (idx < _list.count)
        return _list[idx];
    
    return nil;
}

@end
