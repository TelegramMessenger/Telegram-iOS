#import "TGPhotoEditorToolButtonsView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGImageUtils.h"

#import "TGPhotoEditorInterfaceAssets.h"

#import "TGModernButton.h"

const CGFloat TGPhotoEditorToolButtonsViewSize = 53;

@implementation TGPhotoEditorToolButtonsView
{
    UIView *_backgroundView;
    UIView *_stripeView;
    UIView *_topStripeView;
    
    TGModernButton *_cancelButton;
    TGModernButton *_confirmButton;
    
    CGFloat _landscapeSize;
}

- (instancetype)initWithCancelButton:(NSString *)cancelButton doneButton:(NSString *)doneButton
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _backgroundView = [[UIView alloc] initWithFrame:self.bounds];
        _backgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarBackgroundColor];
        [self addSubview:_backgroundView];
        
        _topStripeView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
        _topStripeView.backgroundColor = UIColorRGB(0x242424);
        [self addSubview:_topStripeView];
        
        _stripeView = [[UIView alloc] initWithFrame:CGRectZero];
        _stripeView.backgroundColor = UIColorRGB(0x242424);
        [self addSubview:_stripeView];
        
        _cancelButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
        _cancelButton.titleLabel.font = TGSystemFontOfSize(17);
        [_cancelButton setTitle:cancelButton forState:UIControlStateNormal];
        [_cancelButton setTitleColor:[UIColor whiteColor]];
        [_cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_cancelButton];
        
        _confirmButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
        _confirmButton.titleLabel.font = TGSystemFontOfSize(17);
        [_confirmButton setTitle:doneButton forState:UIControlStateNormal];
        [_confirmButton setTitleColor:UIColorRGB(0x5cc0ff)];
        [_confirmButton addTarget:self action:@selector(confirmButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_confirmButton];
    }
    return self;
}

- (void)cancelButtonPressed
{
    if (self.cancelPressed != nil)
        self.cancelPressed();
}

- (void)confirmButtonPressed
{
    if (self.confirmPressed != nil)
        self.confirmPressed();
}

- (void)layoutSubviews
{
    _backgroundView.frame = self.bounds;
    
    CGFloat thickness = 1.0f;
    if (TGIsRetina())
        thickness = 0.5f;
    
    if (self.frame.size.width > self.frame.size.height)
    {
        _stripeView.hidden = false;
        _topStripeView.hidden = false;
        _topStripeView.frame = CGRectMake(0, 0, self.frame.size.width, thickness);
        _stripeView.frame = CGRectMake(self.frame.size.width / 2, 0, thickness, self.frame.size.height);
        _cancelButton.frame = CGRectMake(0, 0, CGFloor(self.frame.size.width / 2), self.frame.size.height);
        _confirmButton.frame = CGRectMake(CGFloor(self.frame.size.width / 2), 0, CGFloor(self.frame.size.width / 2), self.frame.size.height);
        _cancelButton.titleLabel.font = TGSystemFontOfSize(17);
        _confirmButton.titleLabel.font = TGSystemFontOfSize(17);
    }
    else
    {
        _stripeView.hidden = true;
        _topStripeView.hidden = true;
        _stripeView.frame = CGRectMake(0, self.frame.size.height / 2, self.frame.size.width, thickness);
        _cancelButton.frame = CGRectMake(0, self.frame.size.height - 44, self.frame.size.width, 44);
        _confirmButton.frame = CGRectMake(0, 0, self.frame.size.width, 44);
        _cancelButton.titleLabel.font = TGSystemFontOfSize(13);
        _confirmButton.titleLabel.font = TGSystemFontOfSize(14);
    }
}

- (void)calculateLandscapeSizeForPossibleButtonTitles:(NSArray *)possibleButtonTitles
{
    CGFloat maxWidth = 0.0f;
    
    for (NSString *title in possibleButtonTitles)
    {
        CGFloat width = 0.0f;
        width = CGCeil([title sizeWithAttributes:@{ NSFontAttributeName:TGSystemFontOfSize(17) }].width - 1);
        
        if (width > maxWidth)
            maxWidth = width;
    }
    
    _landscapeSize = MAX(maxWidth, TGPhotoEditorToolButtonsViewSize);
}

- (CGFloat)landscapeSize
{
    if (_landscapeSize < FLT_EPSILON)
    {
        [self calculateLandscapeSizeForPossibleButtonTitles:@[ [_cancelButton titleForState:UIControlStateNormal], [_confirmButton titleForState:UIControlStateNormal] ]];
    }
    
    return _landscapeSize;
}

@end
