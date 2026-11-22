#import "TGAttachmentPhotoCell.h"
#import <LegacyComponents/TGModernGalleryTransitionView.h>

NSString *const TGAttachmentPhotoCellIdentifier = @"AttachmentPhotoCell";

@interface TGAttachmentPhotoCell () <TGModernGalleryTransitionView>

@end

@implementation TGAttachmentPhotoCell

- (UIImage *)transitionImage
{
    CGFloat scale = 1.0f;
    CGSize scaledBoundsSize = CGSizeZero;
    CGSize scaledImageSize = CGSizeZero;
    
    if (self.imageView.image.size.width > self.imageView.image.size.height)
    {
        scale = self.frame.size.height / self.imageView.image.size.height;
        scaledBoundsSize = CGSizeMake(self.frame.size.width / scale, self.imageView.image.size.height);
        
        scaledImageSize = CGSizeMake(self.imageView.image.size.width * scale, self.imageView.image.size.height * scale);
        
        if (scaledImageSize.width < self.frame.size.width)
        {
            scale = self.frame.size.width / self.imageView.image.size.width;
            scaledBoundsSize = CGSizeMake(self.imageView.image.size.width, self.frame.size.height / scale);
        }
    }
    else
    {
        scale = self.frame.size.width / self.imageView.image.size.width;
        scaledBoundsSize = CGSizeMake(self.imageView.image.size.width, self.frame.size.height / scale);
        
        scaledImageSize = CGSizeMake(self.imageView.image.size.width * scale, self.imageView.image.size.height * scale);
        
        if (scaledImageSize.width < self.frame.size.width)
        {
            scale = self.frame.size.height / self.imageView.image.size.height;
            scaledBoundsSize = CGSizeMake(self.frame.size.width / scale, self.imageView.image.size.height);
        }
    }
    
    CGRect rect = self.bounds;
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) cornerRadius:TGAttachmentMenuCellCornerRadius] addClip];
    
    CGContextScaleCTM(context, scale, scale);
    [self.imageView.image drawInRect:CGRectMake((scaledBoundsSize.width - self.imageView.image.size.width) / 2,
                                                (scaledBoundsSize.height - self.imageView.image.size.height) / 2,
                                                self.imageView.image.size.width,
                                                self.imageView.image.size.height)];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
