#import "TGCameraFlipButton.h"

#import "TGCameraInterfaceAssets.h"
#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

@implementation TGCameraFlipButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.exclusiveTouch = true;
        self.backgroundColor = [TGCameraInterfaceAssets buttonColor];
        self.layer.cornerRadius = 24.0;
        [self setImage:[UIImage imageNamed:@"Camera/Flip"] forState:UIControlStateNormal];
    }
    return self;
}

- (void)setHidden:(BOOL)hidden
{
    self.alpha = hidden ? 0.0f : 1.0f;
    super.hidden = hidden;
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        super.hidden = false;
        self.userInteractionEnabled = false;
        
        [UIView animateWithDuration:0.25f animations:^
        {
            self.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            self.userInteractionEnabled = true;
             
            if (finished)
                self.hidden = hidden;
        }];
    }
    else
    {
        self.alpha = hidden ? 0.0f : 1.0f;
        super.hidden = hidden;
    }
}

@end


@implementation TGCameraCancelButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.exclusiveTouch = true;
        self.backgroundColor = [TGCameraInterfaceAssets buttonColor];
        self.layer.cornerRadius = 24.0;
        [self setImage:[UIImage imageNamed:@"Camera/Cancel"] forState:UIControlStateNormal];
    }
    return self;
}

- (void)setHidden:(BOOL)hidden
{
    self.alpha = hidden ? 0.0f : 1.0f;
    super.hidden = hidden;
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        super.hidden = false;
        self.userInteractionEnabled = false;
        
        [UIView animateWithDuration:0.25f animations:^
        {
            self.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            self.userInteractionEnabled = true;
             
            if (finished)
                self.hidden = hidden;
        }];
    }
    else
    {
        self.alpha = hidden ? 0.0f : 1.0f;
        super.hidden = hidden;
    }
}

@end
