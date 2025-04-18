#import "TGModernToolbarButton.h"

#import <LegacyComponents/LegacyComponents.h>

@implementation TGModernToolbarButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _buttonTitleLabel = [[UILabel alloc] init];
        _buttonTitleLabel.textColor = [UIColor whiteColor];
        _buttonTitleLabel.backgroundColor = [UIColor clearColor];
        _buttonTitleLabel.font = TGSystemFontOfSize(17);
        [self addSubview:_buttonTitleLabel];
        
        [self setTitleColor:[UIColor whiteColor]];
    }
    return self;
}

- (void)sizeToFit
{
    [self.buttonTitleLabel sizeToFit];
    
    CGRect frame = self.frame;
    frame.size.height = self.buttonTitleLabel.frame.size.height;
    frame.size.width = self.buttonTitleLabel.frame.size.width;
    self.frame = frame;
}

- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state
{
    [super setTitleColor:color forState:state];
    
    if (state == UIControlStateNormal)
    {
        _buttonTitleLabel.textColor = color;
    }
}

- (void)setButtonTitle:(NSString *)buttonTitle
{
    _buttonTitle = buttonTitle;
    
    _buttonTitleLabel.text = buttonTitle;
    [_buttonTitleLabel sizeToFit];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    //_buttonTitleLabel.frame = CGRectMake(0.0f, 0.0f, _buttonTitleLabel.frame.size.width, _buttonTitleLabel.frame.size.height);
}

@end
