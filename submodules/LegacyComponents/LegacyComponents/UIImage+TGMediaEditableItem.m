#import "UIImage+TGMediaEditableItem.h"

#import <LegacyComponents/LegacyComponents.h>

#import <objc/runtime.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>

@implementation UIImage (TGMediaEditableItem)

- (bool)isVideo
{
    return false;
}

- (NSString *)uniqueIdentifier
{
    NSString *cachedIdentifier = objc_getAssociatedObject(self, @selector(uniqueIdentifier));
    if (cachedIdentifier == nil)
    {
        cachedIdentifier = [NSString stringWithFormat:@"%ld", lrand48()];
        objc_setAssociatedObject(self, @selector(uniqueIdentifier), cachedIdentifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cachedIdentifier;
}

- (CGSize)originalSize
{
    return self.size;
}

- (SSignal *)thumbnailImageSignal
{
    CGFloat thumbnailImageSide = TGPhotoThumbnailSizeForCurrentScreen().width;
    CGSize size = TGScaleToSize(self.size, CGSizeMake(thumbnailImageSide, thumbnailImageSide));
    
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        UIGraphicsBeginImageContextWithOptions(size, true, 0.0f);
        [self drawInRect:CGRectMake(0, 0, size.width, size.height)];
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        [subscriber putNext:image];
        [subscriber putCompletion];
        
        return nil;
    }] startOn:[SQueue concurrentDefaultQueue]];
}

- (SSignal *)screenImageSignal:(NSTimeInterval)__unused position
{
    CGSize size = TGFitSize(self.size, TGPhotoEditorScreenImageMaxSize());
    
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0f);
        [self drawInRect:CGRectMake(0, 0, size.width, size.height)];
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        [subscriber putNext:image];
        [subscriber putCompletion];
        
        return nil;
    }] startOn:[SQueue concurrentDefaultQueue]];
}

- (SSignal *)originalImageSignal:(NSTimeInterval)__unused position
{
    return [SSignal single:self];
}

@end
