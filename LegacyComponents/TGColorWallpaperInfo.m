#import "TGColorWallpaperInfo.h"

#import "LegacyComponentsInternal.h"

@interface TGColorWallpaperInfo ()
{
    uint32_t _color;
    int _tintColor;
    
    CGFloat _systemAlpha;
    CGFloat _buttonsAlpha;
    CGFloat _highlightedButtonAlpha;
    CGFloat _progressAlpha;
}

@end

@implementation TGColorWallpaperInfo

- (instancetype)initWithColor:(uint32_t)color
{
    return [self initWithColor:color tintColor:0x000000 systemAlpha:0.25f buttonsAlpha:0.35f highlightedButtonAlpha:0.50f progressAlpha:0.35f];
}

- (instancetype)initWithColor:(uint32_t)color tintColor:(int)tintColor systemAlpha:(CGFloat)systemAlpha buttonsAlpha:(CGFloat)buttonsAlpha highlightedButtonAlpha:(CGFloat)highlightedButtonAlpha progressAlpha:(CGFloat)progressAlpha
{
    self = [super init];
    if (self != nil)
    {
        _color = color;
        
        _tintColor = tintColor;
        _systemAlpha = systemAlpha;
        _buttonsAlpha = buttonsAlpha;
        _highlightedButtonAlpha = highlightedButtonAlpha;
        _progressAlpha = progressAlpha;
    }
    return self;
}

- (NSString *)thumbnailUrl
{
    return [[NSString alloc] initWithFormat:@"color://?color=%d", (int)_color];
}

- (NSString *)fullscreenUrl
{
    return [self thumbnailUrl];
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
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), true, 0.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, UIColorRGB(_color).CGColor);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, 1.0f, 1.0f));
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (NSData *)imageData
{
    return nil;
}

- (bool)hasData
{
    return false;
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[TGColorWallpaperInfo class]])
    {
        if (((TGColorWallpaperInfo *)object)->_color == _color &&
            ((TGColorWallpaperInfo *)object)->_tintColor == _tintColor)
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
        @"color": @(_color),
        @"tintColor": @(_tintColor),
        @"systemAlpha": @(_systemAlpha),
        @"buttonsAlpha": @(_buttonsAlpha),
        @"highlightedButtonAlpha": @(_highlightedButtonAlpha),
        @"progressAlpha": @(_progressAlpha)
    };
}

+ (TGWallpaperInfo *)infoWithDictionary:(NSDictionary *)dict
{
    return [[TGColorWallpaperInfo alloc] initWithColor:[dict[@"color"] intValue] tintColor:[dict[@"tintColor"] intValue] systemAlpha:[dict[@"systemAlpha"] floatValue] buttonsAlpha:[dict[@"buttonsAlpha"] floatValue] highlightedButtonAlpha:[dict[@"highlightedButtonAlpha"] floatValue] progressAlpha:[dict[@"progressAlpha"] floatValue]];
}

@end
