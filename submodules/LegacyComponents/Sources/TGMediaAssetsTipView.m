#import "TGMediaAssetsTipView.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGImageUtils.h"
#import "TGFont.h"
#import "TGStringUtils.h"

#import <LegacyComponents/TGModernButton.h>

@interface TGMediaAssetsTipView ()
{
    UIView *_wrapperView;
    UIImageView *_imageView;
    UILabel *_titleLabel;
    UILabel *_textLabel;
    TGModernButton *_doneButton;
}
@end

@implementation TGMediaAssetsTipView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor whiteColor];
        
        _wrapperView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
        [self addSubview:_wrapperView];
        
        _imageView = [[UIImageView alloc] initWithImage:TGComponentsImageNamed(@"AttachmentTipIcons")];
        [self addSubview:_imageView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = UIColorRGB(0x222222);
        _titleLabel.font = TGSystemFontOfSize(19.0f + TGRetinaPixel);
        _titleLabel.text = TGLocalized(@"ShareFileTip.Title");
        [_wrapperView addSubview:_titleLabel];

        _textLabel = [[UILabel alloc] init];
        _textLabel.backgroundColor = [UIColor clearColor];
        _textLabel.textColor = UIColorRGB(0x808080);
        _textLabel.font = TGSystemFontOfSize(15.0f + TGRetinaPixel);
        
        NSString *shareTipText = [[NSString alloc] initWithFormat:TGLocalized(@"ShareFileTip.Text"), [TGStringUtils stringForDeviceType]];
        _textLabel.attributedText = [shareTipText attributedFormattedStringWithRegularFont:TGSystemFontOfSize(15.0f + TGRetinaPixel) boldFont:TGBoldSystemFontOfSize(15.0f + TGRetinaPixel) lineSpacing:3.0f paragraphSpacing:-1.0f alignment:NSTextAlignmentCenter];
        _textLabel.numberOfLines = 0;
        _textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [_wrapperView addSubview:_textLabel];
        
        _doneButton = [[TGModernButton alloc] init];
        [_doneButton setTitle:TGLocalized(@"ShareFileTip.CloseTip") forState:UIControlStateNormal];
        _doneButton.titleLabel.font = TGSystemFontOfSize(18.0f);
        [_doneButton setTitleColor:TGAccentColor()];
        _doneButton.contentEdgeInsets = UIEdgeInsetsMake(8.0f, 20.0f, 8.0f, 20.0f);
        [_doneButton sizeToFit];
        [_doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_doneButton];
    }
    return self;
}

- (void)doneButtonPressed
{
    [UIView animateWithDuration:0.4 animations:^
    {
        self.frame = CGRectMake(0.0f, self.superview.frame.size.height, self.frame.size.width, self.frame.size.height);
    } completion:^(__unused BOOL finished)
    {
        [self removeFromSuperview];
    }];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _imageView.frame = CGRectMake((self.frame.size.width - _imageView.frame.size.width) / 2, 0, _imageView.frame.size.width, _imageView.frame.size.height);
    
    CGFloat padding = 22.0f;
    
    CGSize titleSize = [_titleLabel sizeThatFits:CGSizeMake(self.bounds.size.width - padding * 2.0f, CGFLOAT_MAX)];
    _titleLabel.frame = CGRectMake(padding, CGRectGetMaxY(_imageView.frame) + 22.0f + TGRetinaPixel, titleSize.width, titleSize.height);
    
    CGSize textSize = [_textLabel sizeThatFits:CGSizeMake(self.bounds.size.width - padding * 2.0f, CGFLOAT_MAX)];
    _textLabel.frame = CGRectMake(padding, CGRectGetMaxY(_titleLabel.frame) + 15.0f + TGRetinaPixel, textSize.width, textSize.height);
    
    CGFloat wrapperHeight = CGRectGetMaxY(_textLabel.frame);
    _wrapperView.frame = CGRectMake(0, floor((self.frame.size.height - wrapperHeight) / 2.0f) - 30.0f, self.frame.size.width, wrapperHeight);
    
    _doneButton.frame = CGRectMake(CGFloor((self.bounds.size.width - _doneButton.frame.size.width) / 2.0f), self.frame.size.height - _doneButton.frame.size.height - 16.0f + TGRetinaPixel, _doneButton.frame.size.width, _doneButton.frame.size.height);
}

@end
