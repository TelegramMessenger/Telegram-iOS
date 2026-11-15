//
//  RMIntroPageView.m
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 05.12.13.
//  Copyright (c) 2013 Ilya Rimchikov. All rights reserved.
//

#import "RMIntroPageView.h"

@implementation RMIntroPageView {
    UIScrollView *_textScrollView;
}

#define IPAD ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)

- (id)initWithFrame:(CGRect)frame headline:(NSString*)headline description:(NSString*)description color:(UIColor *)color
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        
        //self.backgroundColor=[UIColor redColor];
        self.opaque=YES;
        _headline=headline;
        
        _textScrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        _textScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        _textScrollView.directionalLockEnabled = YES;
        [self addSubview:_textScrollView];

        UILabel *headlineLabel = [[UILabel alloc] init];
        headlineLabel.text = _headline;
        headlineLabel.textColor = color;
        headlineLabel.textAlignment = NSTextAlignmentCenter;
        headlineLabel.numberOfLines = 0;
        headlineLabel.adjustsFontForContentSizeCategory = YES;
        headlineLabel.accessibilityTraits = UIAccessibilityTraitStaticText | UIAccessibilityTraitHeader;
        _headerLabel = headlineLabel;
      
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineSpacing = IPAD ? 4 : 3;
        style.lineBreakMode = NSLineBreakByWordWrapping;
        style.alignment = NSTextAlignmentCenter;
        

        NSMutableArray *boldRanges = [[NSMutableArray alloc] init];
        
        NSMutableString *cleanText = [[NSMutableString alloc] initWithString:description];
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
        
        _description = [[NSMutableAttributedString alloc]initWithString:cleanText];
        [_description addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:IPAD ? 22.0 : 17.0] range:NSMakeRange(0, _description.length)];
        NSDictionary *boldAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [UIFont boldSystemFontOfSize:IPAD ? 22 : 17.0], NSFontAttributeName, nil];
        for (NSValue *nRange in boldRanges)
        {
            [_description addAttributes:boldAttributes range:[nRange rangeValue]];
        }
        
        [_description addAttribute:NSParagraphStyleAttributeName
                             value:style
                             range:NSMakeRange(0, _description.length)];
        [_description addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, _description.length)];
        
        UILabel *descriptionLabel = [[UILabel alloc] init];
        descriptionLabel.numberOfLines=0;
        descriptionLabel.adjustsFontForContentSizeCategory = YES;
        _descriptionLabel = descriptionLabel;
        
        [_textScrollView addSubview:headlineLabel];
        [_textScrollView addSubview:descriptionLabel];
        [self updateFonts];
        
        
    }
    return self;
}

- (void)updateFonts {
    UITraitCollection *traits = self.traitCollection;
    UIFontMetrics *titleMetrics = [UIFontMetrics metricsForTextStyle:UIFontTextStyleLargeTitle];
    _headerLabel.font = [titleMetrics scaledFontForFont:[UIFont boldSystemFontOfSize:35.0] compatibleWithTraitCollection:traits];

    // UILabel's automatic scaling does not update each font run in attributed text.
    UIFontMetrics *bodyMetrics = [UIFontMetrics metricsForTextStyle:UIFontTextStyleBody];
    _descriptionLabel.font = [bodyMetrics scaledFontForFont:[UIFont systemFontOfSize:IPAD ? 22.0 : 17.0] compatibleWithTraitCollection:traits];
    NSMutableAttributedString *scaledDescription = [_description mutableCopy];
    [_description enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, _description.length) options:0 usingBlock:^(UIFont *font, NSRange range, BOOL *stop) {
        [scaledDescription addAttribute:NSFontAttributeName value:[bodyMetrics scaledFontForFont:font compatibleWithTraitCollection:traits] range:range];
    }];
    _descriptionLabel.attributedText = scaledDescription;
    [self setNeedsLayout];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (![self.traitCollection.preferredContentSizeCategory isEqualToString:previousTraitCollection.preferredContentSizeCategory]) {
        [self updateFonts];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _textScrollView.frame = self.bounds;

    CGFloat inset = 16.0;
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat textWidth = MAX(0.0, width - 2.0 * inset);
    CGSize fittingSize = CGSizeMake(textWidth, CGFLOAT_MAX);
    CGFloat headlineHeight = ceil([_headerLabel sizeThatFits:fittingSize].height);
    CGFloat descriptionHeight = ceil([_descriptionLabel sizeThatFits:fittingSize].height);
    CGFloat headlineY = MAX(0.0, floor(36.0 - headlineHeight / 2.0));
    CGFloat descriptionCenter = 91.5 + (IPAD ? 22.0 : 0.0);
    CGFloat descriptionY = MAX(headlineY + headlineHeight + 8.0, floor(descriptionCenter - descriptionHeight / 2.0));

    _headerLabel.frame = CGRectMake(inset, headlineY, textWidth, headlineHeight);
    _descriptionLabel.frame = CGRectMake(inset, descriptionY, textWidth, descriptionHeight);
    CGFloat viewportHeight = CGRectGetHeight(self.bounds);
    CGFloat contentHeight = MAX(viewportHeight, CGRectGetMaxY(_descriptionLabel.frame) + 8.0);
    _textScrollView.contentSize = CGSizeMake(width, contentHeight);
    _textScrollView.scrollEnabled = contentHeight > viewportHeight;
    _textScrollView.clipsToBounds = _textScrollView.scrollEnabled;
    if (!_textScrollView.scrollEnabled) {
        _textScrollView.contentOffset = CGPointZero;
    }
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
