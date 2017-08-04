#import "TGLocationTitleView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"

@interface TGLocationTitleView ()
{
    UILabel *_titleLabel;
    UILabel *_addressLabel;
}
@end

@implementation TGLocationTitleView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, frame.size.width, 20)];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGBoldSystemFontOfSize(17);
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_titleLabel];

        _addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 21, frame.size.width, 21)];
        _addressLabel.backgroundColor = [UIColor clearColor];
        _addressLabel.font = TGSystemFontOfSize(13.0f);
        _addressLabel.textColor = UIColorRGB(0x787878);
        _addressLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_addressLabel];
    }
    return self;
}

- (NSString *)title
{
    return _titleLabel.text;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
    [self setNeedsLayout];
}

- (NSString *)address
{
    return _addressLabel.text;
}

- (void)setAddress:(NSString *)address
{
    _addressLabel.text = address;
    [self setNeedsLayout];
}

- (UIView *)_findNavigationBar:(UIView *)view
{
    if (view.superview == nil)
        return nil;
    else if ([view.superview isKindOfClass:[UINavigationBar class]])
        return view.superview;
    else
        return [self _findNavigationBar:view.superview];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [_titleLabel sizeToFit];
    [_addressLabel sizeToFit];
    
    CGRect titleFrame = _titleLabel.frame;
    titleFrame.size.width = CGCeil(titleFrame.size.width);
    
    CGRect addressFrame = _addressLabel.frame;
    addressFrame.size.width = CGCeil(addressFrame.size.width);
    
    UIView *navigationBar = [self _findNavigationBar:self];
    CGRect offsetRect = [self.superview convertRect:self.frame toView:navigationBar];
    
    UIEdgeInsets edges = UIEdgeInsetsMake(0, self.backButtonWidth, 0, navigationBar.frame.size.width - self.actionsButtonWidth);
    
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
    {
        if (_addressLabel.text.length > 0)
            titleFrame.origin.y = 5;
        else
            titleFrame.origin.y = 12;
        
        addressFrame.origin.y = 23.5f;
        
        titleFrame.origin.x = (navigationBar.frame.size.width - titleFrame.size.width) / 2;
        if (titleFrame.origin.x < edges.left || CGRectGetMaxX(titleFrame) > edges.right)
        {
            titleFrame.origin.x = edges.left;
            titleFrame.size.width = edges.right - edges.left;
        }
        
        CGFloat titleCenter = CGRectGetMidX(titleFrame);
        addressFrame.origin.x = titleCenter - addressFrame.size.width / 2;
        if (addressFrame.origin.x < edges.left || CGRectGetMaxX(addressFrame) > edges.right)
        {
            addressFrame.origin.x = edges.left;
            addressFrame.size.width = edges.right - edges.left;
        }
    }
    else
    {
        titleFrame.origin.y = 10;
        addressFrame.origin.y = 13;
        
        CGFloat jointWidth = titleFrame.size.width + addressFrame.size.width + 6;
        CGFloat jointOrigin = (navigationBar.frame.size.width - jointWidth) / 2;
        if (jointOrigin < edges.left || jointOrigin + jointWidth > edges.right)
        {
            jointOrigin = edges.left;
            
            CGFloat newJointWidth = edges.right - edges.left;
            addressFrame.size.width -= (jointWidth - newJointWidth);
            jointWidth = newJointWidth;
        }
        
        titleFrame.origin.x = jointOrigin;
        addressFrame.origin.x = jointOrigin + jointWidth - addressFrame.size.width;
    }

    _titleLabel.frame = CGRectOffset(titleFrame, -offsetRect.origin.x, 0);
    _addressLabel.frame = CGRectOffset(addressFrame, -offsetRect.origin.x, 0);
}

@end
