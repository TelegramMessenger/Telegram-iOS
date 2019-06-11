#import "TGMediaAssetFetchResult.h"

#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "TGMediaAsset.h"

@interface TGMediaAssetFetchResult ()
{
    PHFetchResult *_concreteFetchResult;
    NSMutableArray *_assets;
    
    bool _reversed;
}
@end

@implementation TGMediaAssetFetchResult

- (instancetype)initForALAssetsReversed:(bool)reversed
{
    self = [super init];
    if (self != nil)
    {
        _assets = [[NSMutableArray alloc] init];
        _reversed = reversed;
    }
    return self;
}

- (instancetype)initWithPHFetchResult:(PHFetchResult *)fetchResult reversed:(bool)reversed
{
    self = [super init];
    if (self != nil)
    {
        _concreteFetchResult = fetchResult;
        _reversed = reversed;
    }
    return self;
}

- (NSUInteger)count
{
    if (_concreteFetchResult != nil)
        return _concreteFetchResult.count;
    else
        return _assets.count;
}

- (TGMediaAsset *)assetAtIndex:(NSUInteger)index
{
    index = _reversed ? self.count - index - 1 : index;
    
    if (_concreteFetchResult != nil)
        return [[TGMediaAsset alloc] initWithPHAsset:[_concreteFetchResult objectAtIndex:index]];
    else if (index < _assets.count)
        return [_assets objectAtIndex:index];
        
    return nil;
}

- (NSUInteger)indexOfAsset:(TGMediaAsset *)asset
{
    if (asset == nil)
        return NSNotFound;
    
    NSUInteger index = NSNotFound;
    
    if (_concreteFetchResult != nil)
        index = [_concreteFetchResult indexOfObject:asset.backingAsset];
    else if (_assets.count > 0)
        index = [_assets indexOfObject:asset];
    
    if (index != NSNotFound)
        index = _reversed ? self.count - index - 1 : index;
    
    return index;
}

- (NSSet *)itemsIdentifiers
{
    NSMutableSet *itemsIds = [[NSMutableSet alloc] init];
    if (_concreteFetchResult != nil)
    {
        for (PHAsset *asset in _concreteFetchResult)
            [itemsIds addObject:asset.localIdentifier];
    }
    else if (_assets.count > 0)
    {
        for (TGMediaAsset *asset in _assets)
            [itemsIds addObject:asset.uniqueIdentifier];
    }
    return itemsIds;
}

- (void)_appendALAsset:(ALAsset *)asset
{
    if (asset == nil)
        return;

    [_assets addObject:[[TGMediaAsset alloc] initWithALAsset:asset]];
}

@end
