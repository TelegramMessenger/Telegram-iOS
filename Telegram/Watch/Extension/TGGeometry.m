#import "TGGeometry.h"

@implementation TGGeometry

CGSize TGFitSize(CGSize size, CGSize maxSize)
{
    if (size.width < 1.0f)
        return CGSizeZero;
    if (size.height < 1.0f)
        return CGSizeZero;
    
    if (size.width > maxSize.width)
    {
        size.height = (CGFloat)floor((size.height * maxSize.width / size.width));
        size.width = maxSize.width;
    }
    if (size.height > maxSize.height)
    {
        size.width = (CGFloat)floor((size.width * maxSize.height / size.height));
        size.height = maxSize.height;
    }
    return size;
}

CGSize TGFillSize(CGSize size, CGSize maxSize)
{
    if (size.width < 1)
        size.width = 1;
    if (size.height < 1)
        size.height = 1;
    
    if (/*size.width >= size.height && */size.width < maxSize.width)
    {
        size.height = floor(maxSize.width * size.height / MAX(1.0f, size.width));
        size.width = maxSize.width;
    }
    
    if (/*size.width <= size.height &&*/ size.height < maxSize.height)
    {
        size.width = floor(maxSize.height * size.width / MAX(1.0f, size.height));
        size.height = maxSize.height;
    }
    
    return size;
}

CGSize TGScaleToFill(CGSize size, CGSize boundsSize)
{
    if (size.width < 1.0f || size.height < 1.0f)
        return CGSizeMake(1.0f, 1.0f);
    
    CGFloat scale = MAX(boundsSize.width / size.width, boundsSize.height / size.height);
    return CGSizeMake(floor(size.width * scale), floor(size.height * scale));
}

@end
