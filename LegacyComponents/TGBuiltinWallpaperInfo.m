#import "TGBuiltinWallpaperInfo.h"

const int32_t TGBuilitinWallpaperCurrentVersion = 1;

@interface TGBuiltinWallpaperInfo ()
{
    int _builtinId;
    int _tintColor;
    int32_t _version;
    
    CGFloat _systemAlpha;
    CGFloat _buttonsAlpha;
    CGFloat _highlightedButtonAlpha;
    CGFloat _progressAlpha;
}

@end

@implementation TGBuiltinWallpaperInfo

- (instancetype)initWithBuiltinId:(int)builtinId
{
    return [self initWithBuiltinId:builtinId tintColor:0x000000 systemAlpha:0.25f buttonsAlpha:0.35f highlightedButtonAlpha:0.50f progressAlpha:0.35f version:1];
}

- (instancetype)initWithBuiltinId:(int)builtinId tintColor:(int)tintColor systemAlpha:(CGFloat)systemAlpha buttonsAlpha:(CGFloat)buttonsAlpha highlightedButtonAlpha:(CGFloat)highlightedButtonAlpha progressAlpha:(CGFloat)progressAlpha version:(int32_t)version
{
    self = [super init];
    if (self != nil)
    {
        _builtinId = builtinId;
        _tintColor = tintColor;
        _systemAlpha = systemAlpha;
        _buttonsAlpha = buttonsAlpha;
        _highlightedButtonAlpha = highlightedButtonAlpha;
        _progressAlpha = progressAlpha;
        _version = version;
    }
    return self;
}

- (BOOL)isDefault
{
    return _builtinId == 0;
}

- (int32_t)version
{
    return _version;
}

- (NSString *)thumbnailUrl
{
    return [[NSString alloc] initWithFormat:@"builtin-wallpaper://?id=%d&size=thumbnail", _builtinId];
}

- (NSString *)fullscreenUrl
{
    return [[NSString alloc] initWithFormat:@"builtin-wallpaper://?id=%d", _builtinId];
}

- (int)tintColor
{
    return _tintColor;
}

- (CGFloat)systemAlpha
{
    return _systemAlpha;
}

- (CGFloat)buttonsAlpha
{
    return _buttonsAlpha;
}

- (CGFloat)highlightedButtonAlpha
{
    return _highlightedButtonAlpha;
}

- (CGFloat)progressAlpha
{
    return _progressAlpha;
}

- (UIImage *)image
{
    NSString *filePath = [[NSBundle mainBundle] pathForResource:[[NSString alloc] initWithFormat:@"%@builtin-wallpaper-%d", [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ? @"pad-" : @"", _builtinId] ofType:@"jpg"];
    
    return [[UIImage alloc] initWithContentsOfFile:filePath];
}

- (NSData *)imageData
{
    NSString *filePath = [[NSBundle mainBundle] pathForResource:[[NSString alloc] initWithFormat:@"%@builtin-wallpaper-%d", [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ? @"pad-" : @"", _builtinId] ofType:@"jpg"];
    
    return [[NSData alloc] initWithContentsOfFile:filePath];
}

- (bool)hasData
{
    return true;
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[TGBuiltinWallpaperInfo class]])
    {
        if (((TGBuiltinWallpaperInfo *)object)->_builtinId == _builtinId &&
            ((TGBuiltinWallpaperInfo *)object)->_tintColor == _tintColor &&
            ((TGBuiltinWallpaperInfo *)object)->_version == _version)
        {
            return true;
        }
    }
    
    return false;
}

- (NSDictionary *)infoDictionary
{
    return @{
         @"_className": NSStringFromClass([self class]),
         @"builtinId": @(_builtinId),
         @"tintColor": @(_tintColor),
         @"systemAlpha": @(_systemAlpha),
         @"buttonsAlpha": @(_buttonsAlpha),
         @"highlightedButtonAlpha": @(_highlightedButtonAlpha),
         @"progressAlpha": @(_progressAlpha),
         @"version": @(_version)
    };
}

+ (TGWallpaperInfo *)infoWithDictionary:(NSDictionary *)dict
{
    return [[TGBuiltinWallpaperInfo alloc] initWithBuiltinId:[dict[@"builtinId"] intValue] tintColor:[dict[@"tintColor"] intValue] systemAlpha:[dict[@"systemAlpha"] floatValue] buttonsAlpha:[dict[@"buttonsAlpha"] floatValue] highlightedButtonAlpha:[dict[@"highlightedButtonAlpha"] floatValue] progressAlpha:[dict[@"progressAlpha"] floatValue] version:[dict[@"version"] intValue]];
}

@end
