#import "TGRemoteWallpaperInfo.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGRemoteImageView.h>

@interface TGRemoteWallpaperInfo ()
{
    int _remoteId;
    NSString *_thumbnailUri;
    NSString *_fullscreenUri;
    int _tintColor;
}

@end

@implementation TGRemoteWallpaperInfo

- (instancetype)initWithRemoteId:(int)remoteId thumbnailUri:(NSString *)thumbnailUri fullscreenUri:(NSString *)fullscreenUri tintColor:(int)tintColor
{
    self = [super init];
    if (self != nil)
    {
        _remoteId = remoteId;
        _thumbnailUri = thumbnailUri;
        _fullscreenUri = fullscreenUri;
        _tintColor = tintColor;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[TGRemoteWallpaperInfo class]])
    {
        if (((TGRemoteWallpaperInfo *)object)->_remoteId == _remoteId &&
            TGStringCompare(((TGRemoteWallpaperInfo *)object)->_thumbnailUri, _thumbnailUri) &&
            TGStringCompare(((TGRemoteWallpaperInfo *)object)->_fullscreenUri, _fullscreenUri) &&
            ((TGRemoteWallpaperInfo *)object)->_tintColor == _tintColor)
        {
            return true;
        }
    }
    
    return false;
}

- (NSString *)thumbnailUrl
{
    return _thumbnailUri;
}

- (NSString *)fullscreenUrl
{
    return _fullscreenUri;
}

- (int)tintColor
{
    return _tintColor;
}

- (NSData *)imageData
{
    return [[NSData alloc] initWithContentsOfFile:[[TGRemoteImageView sharedCache] pathForCachedData:[self fullscreenUrl]]];
}

- (UIImage *)image
{
    NSData *data = [self imageData];
    if (data != nil)
        return [[UIImage alloc] initWithData:data];
    
    return nil;
}

- (bool)hasData
{
    return true;
}

- (NSDictionary *)infoDictionary
{
    return @{
             @"_className": NSStringFromClass([self class]),
             @"remoteId": @(_remoteId),
             @"thumbnailUri": _thumbnailUri == nil ? @"" : _thumbnailUri,
             @"fullscreenUri": _fullscreenUri == nil ? @"" : _fullscreenUri,
             @"tintColor": @(_tintColor),
             };
}

+ (TGWallpaperInfo *)infoWithDictionary:(NSDictionary *)dict
{
    return [[TGRemoteWallpaperInfo alloc] initWithRemoteId:[dict[@"remoteId"] intValue] thumbnailUri:dict[@"thumbnailUri"] fullscreenUri:dict[@"fullscreenUri"] tintColor:[dict[@"tintColor"] intValue]];
}

@end
