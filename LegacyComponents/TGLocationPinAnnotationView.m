#import "TGLocationPinAnnotationView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"

#import "TGLocationAnnotation.h"

NSString *const TGLocationPinAnnotationKind = @"TGLocationPinAnnotation";

NSString *const TGLocationETAKey = @"eta";

@interface TGLocationPinAnnotationView ()
{
    UIButton *_drivingButton;
    UIImageView *_drivingIconView;
    UILabel *_drivingEtaLabel;
    
    UIImageView *_accessoryView;
}
@end

@implementation TGLocationPinAnnotationView

- (instancetype)initWithAnnotation:(id<MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        self.exclusiveTouch = true;
        
        _titleLabel.font = TGSystemFontOfSize(15.5f);
        _titleLabel.text = annotation.title;
        _titleLabel.textColor = [UIColor blackColor];
        
        _subtitleLabel.font = TGSystemFontOfSize(12.5f);
        _subtitleLabel.textColor = UIColorRGB(0x2289e8);
        
        _drivingButton = [[UIButton alloc] init];
        _drivingButton.adjustsImageWhenHighlighted = false;
        _drivingButton.exclusiveTouch = true;
        [_drivingButton setBackgroundImage:[TGComponentsImageNamed(@"CalloutDrivingBackground.png") resizableImageWithCapInsets:UIEdgeInsetsMake(8, 8, 8, 1)] forState:UIControlStateNormal];
        [_drivingButton setBackgroundImage:[TGComponentsImageNamed(@"CalloutDrivingBackground_Highlighted.png") resizableImageWithCapInsets:UIEdgeInsetsMake(8, 8, 8, 1)] forState:UIControlStateHighlighted];
        [_drivingButton addTarget:self action:@selector(drivingButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_calloutWrapper addSubview:_drivingButton];
        
        _drivingIconView = [[UIImageView alloc] initWithFrame:CGRectMake(11, 16, 22, 15)];
        _drivingIconView.image = TGComponentsImageNamed(@"CalloutDrivingIcon.png");
        [_drivingButton addSubview:_drivingIconView];
        
        _drivingEtaLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 44, 15)];
        _drivingEtaLabel.backgroundColor = [UIColor clearColor];
        _drivingEtaLabel.numberOfLines = 1;
        _drivingEtaLabel.minimumScaleFactor = 8.0f / 11.0f;
        _drivingEtaLabel.textColor = [UIColor whiteColor];
        _drivingEtaLabel.textAlignment = NSTextAlignmentCenter;
        _drivingEtaLabel.adjustsFontSizeToFitWidth = true;
        [_drivingButton addSubview:_drivingEtaLabel];
        
        _accessoryView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 9, 14)];
        _accessoryView.image = TGComponentsImageNamed(@"CalloutAccessory");
        [_calloutWrapper addSubview:_accessoryView];
    }
    return self;
}

- (void)setAnnotation:(id<MKAnnotation>)annotation
{
    [super setAnnotation:annotation];
    
    _titleLabel.text = annotation.title;
    _subtitleLabel.text = annotation.subtitle;

    if ([annotation isKindOfClass:[TGLocationAnnotation class]])
    {
        TGLocationAnnotation *locationAnnotation = (TGLocationAnnotation *)annotation;
        
        NSTimeInterval eta = [locationAnnotation.userInfo[TGLocationETAKey] doubleValue];
        [self setDrivingETA:eta];
    }
}

#pragma mark - Actions

- (void)drivingButtonPressed
{
    if (self.getDirectionsPressed != nil)
        self.getDirectionsPressed();
}

#pragma mark - Properties

- (void)setDrivingETA:(NSTimeInterval)drivingETA
{
    if (drivingETA > 0 && drivingETA < 60 * 60 * 10)
    {
        drivingETA = MAX(drivingETA, 60);
        
        NSInteger minutes = (NSInteger)(drivingETA / 60) % 60;
        NSInteger hours = (NSInteger)(drivingETA / 3600.0f);
        
        NSString *string = nil;
    
        if (hours < 1)
        {
            string = [NSString stringWithFormat:TGLocalized(@"Map.ETAMinutes_any"), [NSString stringWithFormat:@"**%d**", (int)minutes]];
        }
        else
        {
            if (hours == 1 && minutes == 0)
            {
                string = [NSString stringWithFormat:TGLocalized(@"Map.ETAHours_1"), @"**1**"];
            }
            else
            {
                string = [NSString stringWithFormat:TGLocalized(@"Map.ETAHours_any"), [NSString stringWithFormat:@"**%d**:**%02d**", (int)hours, (int)minutes]];
            }
        }
        
        NSMutableArray *boldRanges = [[NSMutableArray alloc] init];
        NSMutableString *cleanText = [[NSMutableString alloc] initWithString:string];
        while (true)
        {
            NSRange startRange = [cleanText rangeOfString:@"**"];
            if (startRange.location == NSNotFound)
                break;
            
            [cleanText deleteCharactersInRange:startRange];
            
            NSRange endRange = [cleanText rangeOfString:@"**"];
            if (endRange.location == NSNotFound)
                break;
            
            [cleanText deleteCharactersInRange:endRange];
            
            [boldRanges addObject:[NSValue valueWithRange:NSMakeRange(startRange.location, endRange.location - startRange.location)]];
        }
        
        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:cleanText];
        [attributedString addAttributes:@{NSForegroundColorAttributeName:[UIColor whiteColor], NSFontAttributeName: TGSystemFontOfSize(11)} range:NSMakeRange(0, attributedString.length)];
        
        NSDictionary *boldAttributes = @{NSFontAttributeName: TGBoldSystemFontOfSize(11)};
        for (NSValue *range in boldRanges)
            [attributedString addAttributes:boldAttributes range:[range rangeValue]];
        
        _drivingEtaLabel.attributedText = attributedString;
    }
    else
    {
        _drivingEtaLabel.attributedText = nil;
    }
}

#pragma mark - Layout

- (void)sizeToFit
{
    CGRect frame = _calloutWrapper.frame;

    CGSize titleLabelSize = [_titleLabel sizeThatFits:CGSizeMake(214, FLT_MAX)];
    CGSize subtitleLabelSize = [_subtitleLabel sizeThatFits:CGSizeMake(214, FLT_MAX)];
    
    CGFloat labelsWidth = MAX(titleLabelSize.width, subtitleLabelSize.width) + 86;
    
    frame.size.width = MIN(300, MAX(labelsWidth, 194));
    frame.size.height = 46;
    
    _calloutWrapper.frame = frame;
}

- (void)layoutSubviews
{
    _drivingButton.frame = CGRectMake(0.5f, 0.5f, 44, _calloutWrapper.frame.size.height - 1);
    
    CGFloat iconViewOriginY = (_drivingButton.frame.size.height - _drivingIconView.frame.size.height) / 2;
    if (_drivingEtaLabel.attributedText.length > 0)
    {
        iconViewOriginY -= 4;
        _drivingEtaLabel.alpha = 1.0f;
    }
    else
    {
        _drivingEtaLabel.alpha = 0.0f;
    }
    _drivingIconView.frame = CGRectMake((_drivingButton.frame.size.width - _drivingIconView.frame.size.width) / 2, iconViewOriginY, _drivingIconView.frame.size.width, _drivingIconView.frame.size.height);
    _drivingEtaLabel.frame = CGRectMake(5, _drivingButton.frame.size.height / 2 + 4, 34, 15);
    
    CGFloat titleLabelOriginY = _calloutWrapper.frame.size.height / 2 - 10;
    CGFloat subtitleLabelOriginY = _calloutWrapper.frame.size.height / 2 - 7;
    if (_subtitleLabel.text.length > 0)
    {
        titleLabelOriginY = 5;
        subtitleLabelOriginY = 25;
        _subtitleLabel.alpha = 1.0f;
    }
    else
    {
        _subtitleLabel.alpha = 0.0f;
    }
    
    _titleLabel.frame = CGRectMake(_drivingButton.frame.size.width + 12, titleLabelOriginY, _calloutWrapper.frame.size.width - 82, 19);
    _subtitleLabel.frame = CGRectMake(_drivingButton.frame.size.width + 12, subtitleLabelOriginY, _calloutWrapper.frame.size.width - 82, 15);
    
    _accessoryView.frame = CGRectMake(_calloutWrapper.frame.size.width - _accessoryView.frame.size.width - 13, (_calloutWrapper.frame.size.height - _accessoryView.frame.size.height) / 2, _accessoryView.frame.size.width, _accessoryView.frame.size.height);
    
    [super layoutSubviews];
}

@end
