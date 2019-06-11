#import "TGModernGalleryImageItem.h"

#import "LegacyComponentsInternal.h"

#import "TGModernGalleryImageItemView.h"

#import <LegacyComponents/TGImageView.h>

@implementation TGModernGalleryImageItem

- (instancetype)initWithUri:(NSString *)uri imageSize:(CGSize)imageSize
{
    self = [super init];
    if (self != nil)
    {
        _uri = uri;
        _imageSize = imageSize;
    }
    return self;
}

- (instancetype)initWithLoader:(dispatch_block_t (^)(TGImageView *, bool))loader imageSize:(CGSize)imageSize
{
    self = [super init];
    if (self != nil)
    {
        _loader = [loader copy];
        _imageSize = imageSize;
    }
    return self;
}

- (instancetype)initWithSignal:(SSignal *)signal imageSize:(CGSize)imageSize
{
    self = [super init];
    if (self != nil)
    {
        _loader = [^(TGImageView *imageView, bool synchronous)
        {
            [imageView setSignal:(synchronous ? [signal wait:1.0] : signal)];
            return nil;
        } copy];
        _imageSize = imageSize;
    }
    return self;
}

- (Class)viewClass
{
    return [TGModernGalleryImageItemView class];
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[TGModernGalleryImageItem class]])
    {
        if (!TGStringCompare(_uri, ((TGModernGalleryImageItem *)object).uri))
            return false;
        
        if (!CGSizeEqualToSize(_imageSize, ((TGModernGalleryImageItem *)object).imageSize))
            return false;
        
        return true;
    }
    
    return false;
}

@end
