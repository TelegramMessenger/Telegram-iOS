#import "TGAttachmentMenuCell.h"
#import <LegacyComponents/TGMenuSheetView.h>
#import <LegacyComponents/TGMenuSheetController.h>
#import "LegacyComponentsInternal.h"

const CGFloat TGAttachmentMenuCellCornerRadius = 5.5f;

@implementation TGAttachmentMenuCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.clipsToBounds = true;
        
        if (TGMenuSheetUseEffectView)
        {
            self.backgroundColor = [UIColor clearColor];
            self.layer.cornerRadius = TGAttachmentMenuCellCornerRadius;
        }
        else
        {
            self.backgroundColor = [UIColor whiteColor];
            
            static dispatch_once_t onceToken;
            static UIImage *cornersImage;
            dispatch_once(&onceToken, ^
            {
                CGRect rect = CGRectMake(0, 0, TGAttachmentMenuCellCornerRadius * 2 + 1.0f, TGAttachmentMenuCellCornerRadius * 2 + 1.0f);
                
                UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
                CGContextRef context = UIGraphicsGetCurrentContext();
                
                CGContextSetFillColorWithColor(context, UIColorRGB(0x222f40).CGColor);
                CGContextFillRect(context, rect);
                
                CGContextSetBlendMode(context, kCGBlendModeClear);
                
                CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
                CGContextFillEllipseInRect(context, rect);
                
                cornersImage = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(TGAttachmentMenuCellCornerRadius, TGAttachmentMenuCellCornerRadius, TGAttachmentMenuCellCornerRadius, TGAttachmentMenuCellCornerRadius)];
                
                UIGraphicsEndImageContext();
            });
            
            _cornersView = [[UIImageView alloc] initWithImage:cornersImage];
            _cornersView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _cornersView.frame = self.bounds;
            [self addSubview:_cornersView];
        }
    }
    return self;
}

- (void)setPallete:(TGMenuSheetPallete *)pallete
{
    _pallete = pallete;
    
    self.backgroundColor = pallete.backgroundColor;
    _cornersView.image = pallete.cornersImage;
}

@end
