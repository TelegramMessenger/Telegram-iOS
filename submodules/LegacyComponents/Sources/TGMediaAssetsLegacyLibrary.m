#import "TGMediaAssetsLegacyLibrary.h"

#import <AssetsLibrary/AssetsLibrary.h>

#import <LegacyComponents/TGObserverProxy.h>

@interface TGMediaAssetsLegacyLibrary ()
{
    ALAssetsLibrary *_assetsLibrary;
    TGObserverProxy *_assetsChangeObserver;
    SPipe *_libraryChangePipe;
}
@end

@implementation TGMediaAssetsLegacyLibrary

- (instancetype)initForAssetType:(TGMediaAssetType)assetType
{
    self = [super initForAssetType:assetType];
    if (self != nil)
    {
        _assetsLibrary = [[ALAssetsLibrary alloc] init];
        _assetsChangeObserver = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(assetsLibraryDidChange:) name:ALAssetsLibraryChangedNotification];
        _libraryChangePipe = [[SPipe alloc] init];
    }
    return self;
}

- (SSignal *)assetWithIdentifier:(NSString *)identifier
{
    if (identifier.length == 0)
        return [SSignal fail:nil];
    
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        [_assetsLibrary assetForURL:[NSURL URLWithString:identifier] resultBlock:^(ALAsset *asset)
        {
            if (asset != nil)
            {
                [subscriber putNext:[[TGMediaAsset alloc] initWithALAsset:asset]];
                [subscriber putCompletion];
            }
            else
            {
                [subscriber putError:nil];
            }
        } failureBlock:^(__unused NSError *error)
        {
            [subscriber putError:nil];
        }];
        
        return nil;
    }];
}

- (SSignal *)assetGroups
{
    SSignal *(^groupsSignal)(void) = ^
    {
        return [[[[[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [_assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *assetsGroup, __unused BOOL *stop)
            {
                if (assetsGroup != nil)
                {
                    if (self.assetType != TGMediaAssetAnyType)
                        [assetsGroup setAssetsFilter:[TGMediaAssetsLegacyLibrary _assetsFilterForAssetType:self.assetType]];
                    
                    TGMediaAssetGroup *group = [[TGMediaAssetGroup alloc] initWithALAssetsGroup:assetsGroup];
                    [subscriber putNext:group];
                }
                else
                {
                    [subscriber putCompletion];
                }
            } failureBlock:^(NSError *error)
            {
                [subscriber putError:error];
            }];
            
            return nil;
        }] then:[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [_assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *assetsGroup, __unused BOOL *stop)
            {
                if (assetsGroup != nil)
                {
                    if ([[assetsGroup valueForProperty:ALAssetsGroupPropertyType] integerValue] == ALAssetsGroupSavedPhotos)
                    {
                        TGMediaAssetGroup *group = [[TGMediaAssetGroup alloc] initWithALAssetsGroup:assetsGroup subtype:TGMediaAssetGroupSubtypeVideos];
                        [subscriber putNext:group];
                        [subscriber putCompletion];
                    }
                }
                else
                {
                    [subscriber putCompletion];
                }
            } failureBlock:^(NSError *error)
            {
                [subscriber putError:error];
            }];
            
            return nil;
        }]] reduceLeft:[[NSMutableArray alloc] init] with:^id(NSMutableArray *groups, id group)
        {
            [groups addObject:group];
            return groups;
        }] map:^NSMutableArray *(NSMutableArray *groups)
        {
            [groups sortUsingFunction:TGMediaAssetGroupComparator context:nil];
            return groups;
        }] startOn:_queue];
    };
    
    SSignal *updateSignal = [[self libraryChanged] mapToSignal:^SSignal *(__unused id change)
    {
        return groupsSignal();
    }];
    
    return [groupsSignal() then:updateSignal];
}

- (SSignal *)cameraRollGroup
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        [_assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop)
        {
            if (group != nil)
            {
                if (self.assetType != TGMediaAssetAnyType)
                    [group setAssetsFilter:[TGMediaAssetsLegacyLibrary _assetsFilterForAssetType:self.assetType]];

                [subscriber putNext:[[TGMediaAssetGroup alloc] initWithALAssetsGroup:group]];
                [subscriber putCompletion];

                if (stop != NULL)
                    *stop = true;
            }
            else
            {
                [subscriber putError:nil];
            }
        } failureBlock:^(NSError *error)
        {
            [subscriber putError:error];
        }];

        return nil;
    }];
}

- (SSignal *)assetsOfAssetGroup:(TGMediaAssetGroup *)assetGroup reversed:(bool)reversed
{
    NSParameterAssert(assetGroup);
    
    SSignal *(^fetchSignal)(TGMediaAssetGroup *) = ^SSignal *(TGMediaAssetGroup *group)
    {
        return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            TGMediaAssetFetchResult *mediaFetchResult = [[TGMediaAssetFetchResult alloc] initForALAssetsReversed:reversed];
            
            NSEnumerationOptions options = kNilOptions;
            if (group.isReversed)
                options = NSEnumerationReverse;
            
            [group.backingAssetsGroup enumerateAssetsWithOptions:options usingBlock:^(ALAsset *asset, __unused NSUInteger index, __unused BOOL *stop)
            {
                if (asset != nil && (assetGroup.subtype != TGMediaAssetGroupSubtypeVideos || [[asset valueForProperty:ALAssetPropertyType] isEqualToString:ALAssetTypeVideo]))
                {
                    [mediaFetchResult _appendALAsset:asset];
                }
            }];
            
            [subscriber putNext:mediaFetchResult];
            [subscriber putCompletion];
            
            return nil;
        }] startOn:_queue];
    };
    
    SSignal *updateSignal = [[self libraryChanged] mapToSignal:^SSignal *(__unused id change)
    {
        return fetchSignal(assetGroup);
    }];
    
    return [fetchSignal(assetGroup) then:updateSignal];
}

- (SSignal *)updatedAssetsForAssets:(NSArray *)assets
{
    SSignal *(^updatedAssetSignal)(TGMediaAsset *) = ^SSignal *(TGMediaAsset *asset)
    {
        return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [_assetsLibrary assetForURL:asset.url resultBlock:^(ALAsset *asset)
            {
                if (asset != nil)
                {
                    TGMediaAsset *updatedAsset = [[TGMediaAsset alloc] initWithALAsset:asset];
                    [subscriber putNext:updatedAsset];
                    [subscriber putCompletion];
                }
                else
                {
                    [subscriber putError:nil];
                }
            } failureBlock:^(__unused NSError *error)
            {
                [subscriber putError:nil];
            }];
            
            return nil;
        }] catch:^SSignal *(__unused id error)
        {
            return [SSignal complete];
        }];
    };
    
    NSMutableArray *signals = [[NSMutableArray alloc] init];
    for (TGMediaAsset *asset in assets)
        [signals addObject:updatedAssetSignal(asset)];
    
    SSignal *combinedSignal = nil;
    for (SSignal *signal in signals)
    {
        if (combinedSignal == nil)
            combinedSignal = signal;
        else
            combinedSignal = [combinedSignal then:signal];
    }
    
    return [combinedSignal reduceLeft:[[NSMutableArray alloc] init] with:^id(NSMutableArray *array, TGMediaAsset *updatedAsset)
    {
        [array addObject:updatedAsset];
        return array;
    }];
}

- (SSignal *)filterDeletedAssets:(NSArray *)assets
{
    SSignal *(^assetDeletedSignal)(TGMediaAsset *) = ^SSignal *(TGMediaAsset *asset)
    {
        return [[[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [_assetsLibrary assetForURL:asset.url resultBlock:^(ALAsset *asset)
            {
                [subscriber putNext:@(asset != nil)];
                [subscriber putCompletion];
            } failureBlock:^(__unused NSError *error)
            {
                [subscriber putNext:@(false)];
                [subscriber putCompletion];
            }];
            
            return nil;
        }] filter:^bool(NSNumber *exists)
        {
            return !exists.boolValue;
        }] map:^TGMediaAsset *(__unused id exists)
        {
            return asset;
        }];
    };
    
    NSMutableArray *signals = [[NSMutableArray alloc] init];
    for (TGMediaAsset *asset in assets)
        [signals addObject:assetDeletedSignal(asset)];
    
    SSignal *combinedSignal = nil;
    for (SSignal *signal in signals)
    {
        if (combinedSignal == nil)
            combinedSignal = signal;
        else
            combinedSignal = [combinedSignal then:signal];
    }
    
    return [combinedSignal reduceLeft:[[NSMutableArray alloc] init] with:^id(NSMutableArray *array, TGMediaAsset *deletedAsset)
    {
        [array addObject:deletedAsset];
        return array;
    }];
}

#pragma mark -

- (void)assetsLibraryDidChange:(NSNotification *)__unused notification
{
    __strong TGMediaAssetsLegacyLibrary *strongSelf = self;
    if (strongSelf != nil)
        strongSelf->_libraryChangePipe.sink([SSignal single:@(true)]);
}

- (SSignal *)libraryChanged
{
    return [[_libraryChangePipe.signalProducer() map:^SSignal *(id data) {
        return [[SSignal single:data] delay:0.5 onQueue:_queue];
    }] switchToLatest];
}

#pragma mark -

- (SSignal *)saveAssetWithImage:(UIImage *)image
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        [_assetsLibrary writeImageToSavedPhotosAlbum:image.CGImage orientation:(ALAssetOrientation)image.imageOrientation completionBlock:^(NSURL *assetURL, NSError *error)
        {
            if (assetURL != nil && error == nil)
                [subscriber putCompletion];
            else
                [subscriber putError:error];
        }];
        
        return nil;
    }];
}

- (SSignal *)saveAssetWithImageData:(NSData *)imageData
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        [_assetsLibrary writeImageDataToSavedPhotosAlbum:imageData metadata:nil completionBlock:^(NSURL *assetURL, NSError *error)
        {
            if (assetURL != nil && error == nil)
                [subscriber putCompletion];
            else
                [subscriber putError:error];
        }];
        
        return nil;
    }];
}

- (SSignal *)_saveAssetWithUrl:(NSURL *)url isVideo:(bool)isVideo
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        void (^writeCompletionBlock)(NSURL *, NSError *) = ^(NSURL *assetURL, NSError *error)
        {
            if (assetURL != nil && error == nil)
                [subscriber putCompletion];
            else
                [subscriber putError:error];
        };
        
        if (!isVideo)
        {
            NSData *data = [[NSData alloc] initWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
            [_assetsLibrary writeImageDataToSavedPhotosAlbum:data metadata:nil completionBlock:writeCompletionBlock];
        }
        else
        {
            [_assetsLibrary writeVideoAtPathToSavedPhotosAlbum:url completionBlock:writeCompletionBlock];
        }
        
        return nil;
    }];
}

+ (ALAssetsFilter *)_assetsFilterForAssetType:(TGMediaAssetType)assetType
{
    switch (assetType)
    {
        case TGMediaAssetPhotoType:
            return [ALAssetsFilter allPhotos];
            
        case TGMediaAssetVideoType:
            return [ALAssetsFilter allVideos];
            
        default:
            return [ALAssetsFilter allAssets];
    }
}

+ (SSignal *)authorizationStatusSignal
{
    if (TGMediaLibraryCachedAuthorizationStatus != TGMediaLibraryAuthorizationStatusNotDetermined)
        return [SSignal single:@(TGMediaLibraryCachedAuthorizationStatus)];
    
    return [SSignal single:@(TGMediaLibraryAuthorizationStatusAuthorized)];
}

+ (void)requestAuthorizationForAssetType:(TGMediaAssetType)assetType completion:(void (^)(TGMediaLibraryAuthorizationStatus, TGMediaAssetGroup *))completion
{
    TGMediaLibraryAuthorizationStatus currentStatus = [self authorizationStatus];
    if (currentStatus == TGMediaLibraryAuthorizationStatusDenied || currentStatus == TGMediaLibraryAuthorizationStatusRestricted)
    {
        completion(currentStatus, nil);
    }
    else
    {
        TGMediaAssetsLibrary *library = [self libraryForAssetType:assetType];
        [[library cameraRollGroup] startWithNext:^(TGMediaAssetGroup *group)
        {
            TGMediaLibraryCachedAuthorizationStatus = [self authorizationStatus];
            completion([self authorizationStatus], group);
        } error:^(__unused id error)
        {
            TGMediaLibraryCachedAuthorizationStatus = [self authorizationStatus];
            completion([self authorizationStatus], nil);
        } completed:nil];
    }
}

+ (TGMediaLibraryAuthorizationStatus)authorizationStatus
{
    return [self _authorizationStatusForALAuthorizationStatus:[ALAssetsLibrary authorizationStatus]];
}

+ (TGMediaLibraryAuthorizationStatus)_authorizationStatusForALAuthorizationStatus:(ALAuthorizationStatus)status
{
    switch (status)
    {
        case ALAuthorizationStatusRestricted:
            return TGMediaLibraryAuthorizationStatusRestricted;
            
        case ALAuthorizationStatusDenied:
            return TGMediaLibraryAuthorizationStatusDenied;
            
        case ALAuthorizationStatusAuthorized:
            return TGMediaLibraryAuthorizationStatusAuthorized;
            
        default:
            return TGMediaLibraryAuthorizationStatusNotDetermined;
    }
}

@end
