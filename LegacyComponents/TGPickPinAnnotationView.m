#import "TGPickPinAnnotationView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGColor.h"
#import "TGImageUtils.h"

NSString * const TGPickPinAnnotationKind = @"TGPickPinAnnotationKind";

@implementation TGPickPinAnnotationView

- (instancetype)initWithAnnotation:(id<MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        self.image = [[UIImage alloc] init];

        _titleLabel.font = TGIsRetina() ? TGBoldSystemFontOfSize(16.5f) : TGBoldSystemFontOfSize(16);
        _titleLabel.text = annotation.title;
        _titleLabel.textColor = UIColorRGB(0x2385df);
        
        _subtitleLabel.font = TGSystemFontOfSize(12.5f);
        _subtitleLabel.textColor = UIColorRGB(0xa6a6a6);
    }
    return self;
}

- (void)setAnnotation:(id<MKAnnotation>)annotation
{
    [super setAnnotation:annotation];
    
    _titleLabel.text = annotation.title;
    
    if (annotation.subtitle.length == 0)
        _subtitleLabel.text = TGLocalized(@"Map.Locating");
    else
        _subtitleLabel.text = annotation.subtitle;
}

- (void)setHidden:(BOOL)hidden
{
    [self setHidden:hidden animated:false];
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        super.hidden = false;
        [UIView animateWithDuration:0.2f animations:^
        {
            self.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
                super.hidden = hidden;
        }];
    }
    else
    {
        self.alpha = hidden ? 0.0f : 1.0f;
        super.hidden = hidden;
    }
}

#pragma mark - Layout

- (void)sizeToFit
{
    CGRect frame = _calloutWrapper.frame;
    
    CGFloat titleLabelWidth = CGCeil([_titleLabel sizeThatFits:CGSizeMake(214, FLT_MAX)].width);
    CGFloat subtitleLabelWidth = CGCeil([_subtitleLabel sizeThatFits:CGSizeMake(214, FLT_MAX)].width);
    
    CGFloat labelsWidth = MAX(titleLabelWidth, subtitleLabelWidth) + 24;
    
    frame.size.width = MIN(300, MAX(labelsWidth, 175));
    frame.size.height = 46;
    
    _calloutWrapper.frame = frame;
}

- (void)layoutSubviews
{    
    _titleLabel.frame = CGRectMake(12, 5, _calloutWrapper.frame.size.width - 24, 19);
    _subtitleLabel.frame = CGRectMake(12, 25, _calloutWrapper.frame.size.width - 24, 15);
    
    [super layoutSubviews];
}

@end
