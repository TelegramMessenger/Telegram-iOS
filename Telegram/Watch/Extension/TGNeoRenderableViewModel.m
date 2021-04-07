#import "TGNeoRenderableViewModel.h"

@implementation TGNeoRenderableViewModel

- (CGSize)layoutWithContainerSize:(CGSize)containerSize
{
    return CGSizeZero;
}

+ (SSignal *)renderSignalForViewModel:(TGNeoRenderableViewModel *)viewModel
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        CGFloat scale = 2.0f;
        CGSize size = viewModel.contentSize;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        
        CGContextRef context = CGBitmapContextCreate(NULL,
                                                     size.width * scale, size.height * scale,
                                                     8, size.width * scale * 4, colorSpace,
                                                     kCGImageAlphaPremultipliedFirst);
        CFRelease(colorSpace);
        
        if (context == nil)
        {
            [subscriber putError:nil];
            return nil;
        }
        
        CGContextScaleCTM(context, scale, -scale);
        CGContextTranslateCTM(context, 0, -size.height);
        
        [viewModel drawInContext:context];

        CGImageRef imgRef = CGBitmapContextCreateImage(context);
        if (imgRef == nil)
        {
            CFRelease(context);
            return nil;
        }
        
        UIImage *image = [UIImage imageWithCGImage:imgRef];
        CFRelease(imgRef);
        CFRelease(context);

        [subscriber putNext:image];
        [subscriber putCompletion];
        
        return nil;
    }];
}

@end
