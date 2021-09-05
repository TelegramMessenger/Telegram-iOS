#import "TGMenuView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGImageUtils.h"

#import <QuartzCore/QuartzCore.h>

#pragma mark -

static CGFloat diameter = 16.0f;

static UIColor *highlightColor() {
    static UIColor *color = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = [UIColor colorWithWhite:1.0f alpha:0.25f];
    });
    return color;
}

static UIImage *menuBackgroundMask() {
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIColor *color = [UIColor whiteColor];
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
        image = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:(NSInteger)(diameter / 2.0f) topCapHeight:(NSInteger)(diameter / 2.0f)];
        UIGraphicsEndImageContext();
    });
    return image;
}

static UIImage *menuHighlightedBackground() {
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIColor *color = highlightColor();
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
        image = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:(NSInteger)(diameter / 2.0f) topCapHeight:(NSInteger)(diameter / 2.0f)];
        UIGraphicsEndImageContext();
    });
    return image;
}

static CGFloat pagerButtonWidth = 32.0f;
static UIImage *pagerLeftButtonImage() {
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = CGSizeMake(pagerButtonWidth, 36.0f);
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, size.width / 2.0f, size.height / 2.0f);
        CGContextScaleCTM(context, -0.5f, 0.5f);
        CGContextTranslateCTM(context, -size.width / 2.0f + 8.0f, -size.height / 2.0f + 7.0f);
        TGDrawSvgPath(context, @"M0,0 L0,22 L18,11 L0,0 L0,0 Z ");
        CGContextSetFillColorWithColor(context, highlightColor().CGColor);
        CGContextRestoreGState(context);
        
        CGContextSetFillColorWithColor(context, highlightColor().CGColor);
        CGContextFillRect(context, CGRectMake(size.width - 1.0f, 0.0f, 1.0f, size.height));
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

static UIImage *pagerLeftButtonHighlightedImage() {
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = CGSizeMake(pagerButtonWidth, 36.0f);
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();

        CGContextSetFillColorWithColor(context, highlightColor().CGColor);
        [menuHighlightedBackground() drawInRect:CGRectMake(0.0f, 0.0f, size.width * 2.0f, size.height)];
        
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, size.width / 2.0f, size.height / 2.0f);
        CGContextScaleCTM(context, -0.5f, 0.5f);
        CGContextTranslateCTM(context, -size.width / 2.0f + 8.0f, -size.height / 2.0f + 7.0f);
        TGDrawSvgPath(context, @"M0,0 L0,22 L18,11 L0,0 L0,0 Z ");
        CGContextSetFillColorWithColor(context, highlightColor().CGColor);
        CGContextRestoreGState(context);
        
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

@protocol TGMenuButtonViewDelegate <NSObject>

- (void)menuButtonHighlighted;

@end

@interface TGMenuButtonView () {
    UIView *_highlightedView;
}

@property (nonatomic) bool highlightDisabled;
@property (nonatomic) bool isOptional;
@property (nonatomic) bool isTrailing;
@property (nonatomic, weak) id<TGMenuButtonViewDelegate> delegate;
@property (nonatomic) bool isMultiline;
@property (nonatomic) CGFloat maxWidth;

@end

@implementation TGMenuButtonView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _highlightedView = [[UIView alloc] init];
        _highlightedView.backgroundColor = highlightColor();
        [self addSubview:_highlightedView];
        _highlightedView.hidden = true;
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    bool selected = self.selected;
    
    __strong id<TGMenuButtonViewDelegate> delegate = _delegate;
    [delegate menuButtonHighlighted];
    
    highlighted = highlighted || selected;
    
    _highlightedView.hidden = !(highlighted || selected) || _highlightDisabled;
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    bool highlighted = self.highlighted;
    
    __strong id<TGMenuButtonViewDelegate> delegate = _delegate;
    [delegate menuButtonHighlighted];
    
    selected = selected || highlighted;
    
    _highlightedView.hidden = !(highlighted || selected) || _highlightDisabled;
}

- (void)sizeToFit
{
    NSString *title = [self attributedTitleForState:UIControlStateNormal].string;
    if (title.length == 0)
        title = [self titleForState:UIControlStateNormal];
    
    if (title.length > 0)
    {
        if (self.isMultiline)
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            CGSize size = [title sizeWithFont:self.titleLabel.font constrainedToSize:CGSizeMake(self.maxWidth - 18.0f, FLT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
#pragma clang diagnostic pop
            self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, ceil(size.width) + 18, MAX(41.0f, ceil(size.height) + 20.0f));
        }
        else
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, [title sizeWithFont:self.titleLabel.font].width + 34, 41);
#pragma clang diagnostic pop
        }
    }
    else
    {
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.imageView.frame.size.width + 24.0f, 41);
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _highlightedView.frame = CGRectMake(0.0f, -20.0f, self.frame.size.width, self.frame.size.height + 40.0f);
}

@end

#pragma mark -

@interface TGMenuView () <TGMenuButtonViewDelegate, UIScrollViewDelegate>
{
    NSDictionary *_userInfo;
    
    UIScrollView *_buttonContainer;
    UIView *_buttonContainerContainer;
    UIButton *_leftPagerButton;
    UIButton *_rightPagerButton;
    
    UIImageView *_containerMaskView;
}

@property (nonatomic, strong) NSMutableArray *buttonViews;
@property (nonatomic, strong) NSMutableArray *separatorViews;
@property (nonatomic, strong) NSArray *buttonDescriptions;

@property (nonatomic) CGFloat arrowLocation;
@property (nonatomic) bool arrowOnTop;

@property (nonatomic, strong) UIImageView *arrowTopView;
@property (nonatomic, strong) UIImageView *arrowBottomView;

@property (nonatomic, strong) ASHandle *watcherHandle;

@end

@implementation TGMenuView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.alpha = 0.0f;
        self.layer.anchorPoint = CGPointMake(0.5f, 1.0f);
        self.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
        
        _maxWidth = 310.0f;
        
        _arrowTopView = [[UIImageView alloc] init];
        _arrowTopView.frame = CGRectMake(0.0f, 0.0f, 20.0f, 12.0f);
        [self addSubview:_arrowTopView];
        
        _arrowBottomView = [[UIImageView alloc] init];
        _arrowBottomView.frame = CGRectMake(0.0f, 0.0f, 20.0f, 14.5f);
        [self addSubview:_arrowBottomView];
        
        _buttonContainerContainer = [[UIView alloc] init];
        
        if (iosMajorVersion() >= 8) {
            UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight]];
            effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            effectView.frame = CGRectMake(0.0f, -20.0f, 0.0f, 40.0f);
            [_buttonContainerContainer addSubview:effectView];
        }
        
        UIView *effectView = [[UIView alloc] init];
        effectView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:iosMajorVersion() >= 8 ? 0.8f : 0.9f];
        effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        effectView.frame = CGRectMake(0.0f, -20.0f, 0.0f, 40.0f);
        [_buttonContainerContainer addSubview:effectView];
        
        [self addSubview:_buttonContainerContainer];
        
        _buttonContainer = [[UIScrollView alloc] init];
        _buttonContainer.clipsToBounds = true;
        _buttonContainer.alwaysBounceHorizontal = false;
        _buttonContainer.alwaysBounceVertical = false;
        _buttonContainer.showsHorizontalScrollIndicator = false;
        _buttonContainer.showsVerticalScrollIndicator = false;
        _buttonContainer.pagingEnabled = true;
        _buttonContainer.delaysContentTouches = false;
        _buttonContainer.canCancelContentTouches = true;
        _buttonContainer.delegate = self;
        _buttonContainer.scrollEnabled = false;
        [_buttonContainerContainer addSubview:_buttonContainer];
        
        _leftPagerButton = [[UIButton alloc] init];
        [_leftPagerButton setBackgroundImage:pagerLeftButtonImage() forState:UIControlStateNormal];
        [_leftPagerButton setBackgroundImage:pagerLeftButtonHighlightedImage() forState:UIControlStateHighlighted];
        [_leftPagerButton addTarget:self action:@selector(pagerButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        _rightPagerButton = [[UIButton alloc] init];
        [_rightPagerButton setBackgroundImage:pagerLeftButtonImage() forState:UIControlStateNormal];
        [_rightPagerButton setBackgroundImage:pagerLeftButtonHighlightedImage() forState:UIControlStateHighlighted];
        _rightPagerButton.transform = CGAffineTransformMakeScale(-1.0f, 1.0f);
        [_rightPagerButton addTarget:self action:@selector(pagerButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_leftPagerButton];
        [self addSubview:_rightPagerButton];
        
        _buttonViews = [[NSMutableArray alloc] init];
        _separatorViews = [[NSMutableArray alloc] init];
        
        _arrowLocation = 50;
    }
    return self;
}

- (void)setButtonsAndActions:(NSArray *)buttonsAndActions watcherHandle:(ASHandle *)watcherHandle
{
    _watcherHandle = watcherHandle;
    
    _buttonDescriptions = buttonsAndActions;
    
    int index = -1;
    for (NSDictionary *dict in buttonsAndActions)
    {
        index++;
        
        NSString *title = nil;
        NSAttributedString *attributedTitle = nil;
        
        id titleValue = [dict objectForKey:@"title"];
        if ([titleValue isKindOfClass:[NSString class]])
            title = titleValue;
        else if ([titleValue isKindOfClass:[NSAttributedString class]])
            attributedTitle = titleValue;
        
        id imageValue = [dict objectForKey:@"image"];
        
        TGMenuButtonView *buttonView = nil;
        
        if (index < (int)_buttonViews.count)
            buttonView = [_buttonViews objectAtIndex:index];
        else
        {
            buttonView = [[TGMenuButtonView alloc] init];
            
            if (self.multiline)
            {
                buttonView.titleLabel.numberOfLines = 0;
                buttonView.isMultiline = true;
                buttonView.maxWidth = _maxWidth;
            }
            
            buttonView.delegate = self;
            [buttonView setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [buttonView setTitleColor:UIColorRGBA(0xffffff, 0.5f) forState:UIControlStateDisabled];
            buttonView.titleLabel.font = TGSystemFontOfSize(14);
            [buttonView addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
            [_buttonViews addObject:buttonView];
            [_buttonContainer addSubview:buttonView];
        }
        
        buttonView.isTrailing = [dict[@"trailing"] boolValue];
        buttonView.isOptional = [dict[@"optional"] boolValue];
        
        if (title)
            [buttonView setTitle:title forState:UIControlStateNormal];
        else if (attributedTitle)
            [buttonView setAttributedTitle:attributedTitle forState:UIControlStateNormal];
        
        if ([imageValue isKindOfClass:[UIImage class]])
        {
            [buttonView setImage:imageValue forState:UIControlStateNormal];
            //buttonView.imageEdgeInsets = UIEdgeInsetsMake(0.0f, 10.0f, 0.0f, 10.0f);
        }
        
        buttonView.selected = false;
    }
    
    while ((int)_buttonViews.count > index + 1)
    {
        TGMenuButtonView *buttonView = [_buttonViews lastObject];
        buttonView.delegate = nil;
        [buttonView removeFromSuperview];
        [_buttonViews removeLastObject];
    }
    
    if (_buttonViews.count != 0) {
        while (_separatorViews.count < _buttonViews.count - 1)
        {
            UIView *separatorView = [[UIImageView alloc] init];
            separatorView.backgroundColor = highlightColor();
            [_buttonContainer addSubview:separatorView];
            [_separatorViews addObject:separatorView];
        }
    }
    
    if (_buttonViews.count != 0) {
        while (_separatorViews.count > _buttonViews.count - 1)
        {
            UIImageView *separatorView = [_separatorViews lastObject];
            [separatorView removeFromSuperview];
            [_separatorViews removeLastObject];
        }
    }
    
    index = -1;
    for (TGMenuButtonView *buttonView in _buttonViews)
    {
        index++;
        
        [buttonView sizeToFit];
        if (index == 0 || index == (int)_buttonViews.count - 1)
        {
            CGRect buttonFrame = buttonView.frame;
            buttonFrame.size.width += 1;
            buttonView.frame = buttonFrame;
        }
    }
    
    [self updateBackgrounds];
    
    [self setNeedsLayout];
}

- (void)setButtonHighlightDisabled:(bool)buttonHighlightDisabled
{
    _buttonHighlightDisabled = buttonHighlightDisabled;
    
    for (TGMenuButtonView *view in _buttonViews)
        view.highlightDisabled = buttonHighlightDisabled;
}

- (void)menuButtonHighlighted
{
    if (self.buttonHighlightDisabled)
        return;
    
    NSInteger highlightedIndex = -1;
    
    bool arrowHighlighted = false;
    
    NSInteger index = -1;
    for (TGMenuButtonView *buttonView in _buttonViews)
    {
        index++;
        
        bool containsArrow = _arrowLocation >= buttonView.frame.origin.x && _arrowLocation < buttonView.frame.origin.x + buttonView.frame.size.width;
        
        if (index == 0)
        {
            if (_arrowLocation < buttonView.frame.size.width)
                containsArrow = true;
        }
        
        if (index == (NSInteger)_buttonViews.count - 1)
        {
            if (_arrowLocation >= buttonView.frame.origin.x)
                containsArrow = true;
        }
        
        if (buttonView.highlighted || buttonView.selected)
        {
            arrowHighlighted = containsArrow;
            highlightedIndex = index;
            break;
        }
    }
}

- (UIImage *)highlightMask {
    UIGraphicsBeginImageContextWithOptions(_buttonContainer.bounds.size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    
    [menuBackgroundMask() drawInRect:CGRectMake(0.0f, 10.0f, _buttonContainer.bounds.size.width, _buttonContainer.bounds.size.height - 20.0f)];
    
    if (!_arrowBottomView.hidden) {
        CGPoint arrow = [_arrowBottomView convertRect:_arrowBottomView.bounds toView:_buttonContainerContainer].origin;
        arrow.x += 1.0f;
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, arrow.x, arrow.y);
        CGContextAddLineToPoint(context, arrow.x + 18.0f, arrow.y);
        CGContextAddLineToPoint(context, arrow.x + 18.0f / 2.0f, arrow.y + 10.0f);
        CGContextClosePath(context);
        CGContextFillPath(context);
    } else if (!_arrowTopView.hidden) {
        CGPoint arrow = [_arrowTopView convertRect:_arrowTopView.bounds toView:_buttonContainerContainer].origin;
        arrow.x += 1.0f;
        arrow.y += 1.0f;
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, arrow.x, arrow.y + 10.0f);
        CGContextAddLineToPoint(context, arrow.x + 18.0f / 2.0f, arrow.y);
        CGContextAddLineToPoint(context, arrow.x + 18.0f, arrow.y + 10.0f);
        CGContextClosePath(context);
        CGContextFillPath(context);
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)updateBackgrounds
{
    NSInteger index = -1;
    for (TGMenuButtonView *buttonView in _buttonViews)
    {
        index++;
        
        UIEdgeInsets titleInset = UIEdgeInsetsMake(0, 0, 1, 0);
        
        if (index == 0)
        {
            //titleInset.left += 2;
        }
        
        if (index == (NSInteger)_buttonViews.count - 1)
        {
            //titleInset.right += 2;
        }
        
        if (_multiline)
        {
            titleInset.left = 9.0f;
            titleInset.right = 9.0f;
        }
        
        buttonView.titleEdgeInsets = titleInset;
    }
}

- (void)sizeToFitToWidth:(CGFloat)maxWidth {
    _maxWidth = maxWidth - 20.0f;
    [self sizeToFit];
}

- (void)sizeToFit
{
    CGAffineTransform transform = self.transform;
    self.transform = CGAffineTransformIdentity;
    
    CGFloat maxWidth = _maxWidth;
    CGFloat buttonHeight = 41.0f;
    
    NSMutableArray *pages = [[NSMutableArray alloc] init];
    NSMutableArray *currentPageButtons = [[NSMutableArray alloc] init];
    CGFloat currentPageWidth = 0.0f;
    
    NSMutableArray *optionalButtons = [[NSMutableArray alloc] init];
    
    for (TGMenuButtonView *buttonView in _buttonViews)
    {
        if (buttonView.isOptional) {
            buttonView.hidden = true;
            [optionalButtons addObject:buttonView];
        } else {
            CGFloat buttonWidth = buttonView.frame.size.width;
            bool added = false;
            if (currentPageWidth + buttonWidth > maxWidth) {
                if (currentPageButtons.count == 0) {
                    [currentPageButtons addObject:buttonView];
                    added = true;
                }
                
                [pages addObject:currentPageButtons];
                currentPageButtons = [[NSMutableArray alloc] init];
                currentPageWidth = 0.0f;
            }
            
            if (!added) {
                currentPageWidth += buttonWidth;
                [currentPageButtons addObject:buttonView];
            }
        }

    }
    
    if (currentPageButtons.count != 0) {
        if (currentPageButtons.count == 1) {
            for (TGMenuButtonView *buttonView in optionalButtons)
            {
                CGFloat buttonWidth = buttonView.frame.size.width;
                if (currentPageWidth + buttonWidth > maxWidth) {
                    break;
                }
                
                buttonView.hidden = false;
                currentPageWidth += buttonWidth;
                [currentPageButtons addObject:buttonView];
            }
        }
        
        [pages addObject:currentPageButtons];
    }
    
    for (NSMutableArray *page in pages) {
        NSUInteger index = 0;
        for (TGMenuButtonView *button in page) {
            if (button.isTrailing) {
                if (index + 1 != page.count) {
                    [page removeObjectAtIndex:index];
                    [page addObject:button];
                }
                break;
            }
            index++;
        }
    }
    
    CGFloat maxPageWidth = 0.0f;

    NSInteger pageIndex = -1;
    for (NSArray *buttons in pages) {
        CGFloat sumWidth = 0.0f;
        NSInteger buttonIndex = -1;
        for (UIView *button in buttons) {
            [button sizeToFit];
            buttonIndex++;
            if (buttonIndex != 0) {
                sumWidth += 1.0f;
            }
            sumWidth += button.frame.size.width;
            
            if (_multiline) {
                buttonHeight = MAX(buttonHeight, button.frame.size.height);
            }
        }
        if (pages.count > 1) {
            if (pageIndex == 0) {
                sumWidth += pagerButtonWidth;
            } else if (pageIndex == (NSInteger)pages.count - 1) {
                sumWidth += pagerButtonWidth;
            } else {
                sumWidth += pagerButtonWidth * 2.0f;
            }
        }
        maxPageWidth = MAX(maxPageWidth, MIN(maxWidth, sumWidth));
    }
    
    NSInteger nextSeparatorIndex = 0;
    
    CGFloat diff = buttonHeight - 41.0f;
    CGFloat currentPageStart = 0.0f;
    pageIndex = -1;
    for (NSArray *buttons in pages) {
        pageIndex++;
        
        CGFloat sumWidth = 0.0f;
        NSInteger buttonIndex = -1;
        for (UIView *button in buttons) {
            buttonIndex++;
            if (buttonIndex != 0) {
                sumWidth += 1.0f;
            }
            sumWidth += button.frame.size.width;
        }
        
        CGFloat leftOffset = 0.0f;
        CGFloat pageContentWidth = maxPageWidth;
        if (pages.count > 1) {
            if (pageIndex == 0) {
                pageContentWidth -= pagerButtonWidth;
            } else if (pageIndex == (NSInteger)pages.count - 1) {
                leftOffset = pagerButtonWidth;
                pageContentWidth -= pagerButtonWidth;
            } else {
                leftOffset = pagerButtonWidth;
                pageContentWidth -= pagerButtonWidth * 2.0f;
            }
        }
        
        CGFloat factor = pageContentWidth / sumWidth;
        CGFloat buttonStart = currentPageStart + leftOffset;
        buttonIndex = -1;
        for (UIView *button in buttons) {
            buttonIndex++;
            
            if (buttonIndex != 0) {
                UIView *separatorView = _separatorViews[nextSeparatorIndex++];
                separatorView.frame = CGRectMake(buttonStart, 0.0f, 1.0f, 36.0f + 20.0f);
                buttonStart += 1.0f;
            }
            
            CGFloat buttonWidth = CGFloor(button.frame.size.width * factor);
            if (buttonIndex == (NSInteger)buttons.count - 1) {
                buttonWidth = MAX(buttonWidth, currentPageStart + leftOffset + pageContentWidth - buttonStart);
            }
            button.frame = CGRectMake(buttonStart, -2.0f + 10.0f, buttonWidth, button.frame.size.height);
            
            buttonStart += buttonWidth;
        }
        
        currentPageStart += maxPageWidth;
    }

    _buttonContainerContainer.frame = CGRectMake(0.0f, 2.0f - 10.0f, maxPageWidth, 36.0f + 20.0f + diff);
    _buttonContainer.frame = _buttonContainerContainer.bounds;
    _buttonContainer.contentSize = CGSizeMake(maxPageWidth * pages.count, _buttonContainer.frame.size.height);
    _buttonContainer.contentOffset = CGPointZero;
    
    _leftPagerButton.frame = CGRectMake(0.0f, 2.0f, pagerButtonWidth, 36.0f);
    _rightPagerButton.frame = CGRectMake(maxPageWidth - pagerButtonWidth, 2.0f, pagerButtonWidth, 36.0f);
    
    //_backgroundView.frame = CGRectMake(0.0f, 2.0f, maxPageWidth, 36.0f);
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, maxPageWidth, buttonHeight);
    
    CGFloat minArrowX = 10.0f;
    CGFloat maxArrowX = self.frame.size.width - 10.0f;
    
    CGFloat arrowX = CGFloor(_arrowLocation - _arrowTopView.frame.size.width / 2);
    arrowX = MIN(MAX(minArrowX, arrowX), maxArrowX);
    
    _arrowTopView.frame = CGRectMake(arrowX, -9.0 + TGScreenPixel, _arrowTopView.frame.size.width, _arrowTopView.frame.size.height);
    _arrowBottomView.frame = CGRectMake(arrowX, 37.0f + diff, _arrowBottomView.frame.size.width, _arrowBottomView.frame.size.height);
    
    _arrowTopView.hidden = !_arrowOnTop;
    _arrowBottomView.hidden = _arrowOnTop;
    
    if (_containerMaskView == nil) {
        _containerMaskView = [[UIImageView alloc] init];
        //[_buttonContainerContainer addSubview:_containerMaskView];
    }
    _containerMaskView.image = [self highlightMask];
    [_containerMaskView sizeToFit];
    _buttonContainerContainer.layer.mask = _containerMaskView.layer;
    
    [self scrollViewDidScroll:_buttonContainer];
    
    self.transform = transform;
}

- (void)showInView:(UIView *)view fromRect:(CGRect)rect
{
    [self showInView:view fromRect:rect animated:true];
}

- (void)showInView:(UIView *)view fromRect:(CGRect)rect animated:(bool)animated
{
    CGAffineTransform transform = self.transform;
    self.transform = CGAffineTransformIdentity;
    
    CGRect frame = self.frame;
    frame.origin.x = CGFloor(rect.origin.x + rect.size.width / 2 - frame.size.width / 2);
    if (frame.origin.x < 4)
        frame.origin.x = 4;
    if (frame.origin.x + frame.size.width > view.frame.size.width - 4)
        frame.origin.x = view.frame.size.width - 4 - frame.size.width;
    
    frame.origin.y = rect.origin.y - frame.size.height - 14;
    if (self.forceArrowOnTop)
    {
        _arrowOnTop = true;
    }
    else
    {
        if (frame.origin.y < 2)
        {
            frame.origin.y = rect.origin.y + rect.size.height + 17;
            if (self.forceCenter || frame.origin.y + frame.size.height > view.frame.size.height - 14)
            {
                frame.origin.y = CGFloor((view.frame.size.height - frame.size.height) / 2);
                _arrowOnTop = false;
            }
            else
            {
                _arrowOnTop = true;
            }
        }
        else
        {
            _arrowOnTop = false;
        }
    }
    
    _arrowLocation = CGFloor(rect.origin.x + rect.size.width / 2) - frame.origin.x;
    
    self.layer.anchorPoint = CGPointMake(MAX(0.0f, MIN(1.0f, _arrowLocation / frame.size.width)), _arrowOnTop ? -0.2f : 1.2f);
    
    self.frame = frame;
    [self setNeedsLayout];
    [self layoutIfNeeded];
    [self sizeToFit];
    
    self.transform = transform;
    
    self.layer.rasterizationScale = [[UIScreen mainScreen] scale];
    self.layer.shouldRasterize = true;
    
    self.alpha = 1.0f;
 
    if (animated)
    {
        [UIView animateWithDuration:0.142 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            self.transform = CGAffineTransformMakeScale(1.07f, 1.07f);
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                [UIView animateWithDuration:0.06 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^
                {
                    self.transform = CGAffineTransformIdentity;
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        self.layer.shouldRasterize = false;
                    }
                }];
            }
        }];
    }
    else
    {
        self.transform = CGAffineTransformIdentity;
        self.alpha = 0.0f;
        [UIView animateWithDuration:0.3 animations:^
        {
            self.alpha = 1.0f;
        }];
    }
}

- (void)hide:(dispatch_block_t)completion
{
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
    {
        self.alpha = 0.0f;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            self.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
            
            if (completion)
                completion();
        }
    }];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    /*_buttonContainer.frame = CGRectMake(0.0f, 2.0f, self.frame.size.width, self.frame.size.height - 5.0f);
    
    float currentX = 0;
    
    NSInteger index = -1;
    for (TGMenuButtonView *buttonView in _buttonViews)
    {
        index++;
        
        buttonView.frame = CGRectMake(currentX, -2.0f, buttonView.frame.size.width, buttonView.frame.size.height);
        currentX += buttonView.frame.size.width;
        [buttonView layoutSubviews];
    }
    
    index = -1;
    for (TGMenuButtonView *buttonView in _buttonViews)
    {
        index++;
        
        CGFloat linePosition = 0.0f;
        CGFloat lineWidth = buttonView.frame.size.width;
        
        if (index > 0)
        {
            UIImageView *separatorView = [_separatorViews objectAtIndex:index - 1];
            separatorView.frame = CGRectMake(buttonView.frame.origin.x - 1, 0.0f, separatorView.image.size.width, 36.0f);
        }
        
        bool containsArrow = _arrowLocation >= buttonView.frame.origin.x && _arrowLocation < buttonView.frame.origin.x + buttonView.frame.size.width;
        
        if (index == 0)
        {
            linePosition += 10;
            lineWidth -= 10;
            
            if (_arrowLocation < buttonView.frame.size.width)
                containsArrow = true;
        }
        
        if (index == (NSInteger)_buttonViews.count - 1)
        {
            lineWidth -= 10;
            
            if (_arrowLocation >= buttonView.frame.origin.x)
                containsArrow = true;
        }
    }*/
}

#pragma mark -

- (void)buttonPressed:(TGMenuButtonView *)buttonView
{
    NSInteger index = -1;
    for (TGMenuButtonView *listButtonView in _buttonViews)
    {
        index++;
        
        if (listButtonView == buttonView)
        {
            buttonView.selected = true;
            
            if (index < (NSInteger)_buttonDescriptions.count)
            {
                NSString *action = [[_buttonDescriptions objectAtIndex:index] objectForKey:@"action"];
                NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
                options[@"action"] = action;
                if (_userInfo != nil)
                    options[@"userInfo"] = _userInfo;
                [_watcherHandle requestAction:@"menuAction" options:options];
            }
            
            if ([self.superview isKindOfClass:[TGMenuContainerView class]])
                [(TGMenuContainerView *)self.superview hideMenu];
            
            break;
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == _buttonContainer) {
        if (scrollView.contentSize.width > scrollView.bounds.size.width + FLT_EPSILON) {
            CGFloat leftDistance = scrollView.contentOffset.x;
            CGFloat rightDistance = scrollView.contentSize.width - (scrollView.contentOffset.x + scrollView.bounds.size.width);
            _leftPagerButton.alpha = MAX(0.0f, MIN(1.0f, leftDistance / _leftPagerButton.frame.size.width));
            _rightPagerButton.alpha = MAX(0.0f, MIN(1.0f, rightDistance / _rightPagerButton.frame.size.width));
        } else {
            _leftPagerButton.alpha = 0.0f;
            _rightPagerButton.alpha = 0.0f;
        }
    }
}

- (void)pagerButtonPressed:(UIView *)button {
    CGFloat targetOffset = _buttonContainer.contentOffset.x;
    
    if (button == _leftPagerButton) {
        NSInteger page = ((NSInteger)_buttonContainer.contentOffset.x) / ((NSInteger)_buttonContainer.bounds.size.width);
        if (page > 0) {
            targetOffset = (page - 1) * _buttonContainer.bounds.size.width;
        }
    } else if (button == _rightPagerButton) {
        NSInteger page = ((NSInteger)_buttonContainer.contentOffset.x) / ((NSInteger)_buttonContainer.bounds.size.width);
        if (page + 1 < (NSInteger)(_buttonContainer.contentSize.width / _buttonContainer.bounds.size.width)) {
            targetOffset = (page + 1) * _buttonContainer.bounds.size.width;
        }
    }
    
    if (ABS(targetOffset - _buttonContainer.contentOffset.x) > FLT_EPSILON) {
        if (iosMajorVersion() >= 7) {
            [UIView animateWithDuration:0.4 delay:0.0 usingSpringWithDamping:0.8f initialSpringVelocity:0.0f options:0 animations:^{
                _buttonContainer.contentOffset = CGPointMake(targetOffset, 0.0f);
            } completion:nil];
        } else {
            [UIView animateWithDuration:0.2 animations:^{
                _buttonContainer.contentOffset = CGPointMake(targetOffset, 0.0f);
            }];
        }
    }
}

@end

#pragma mark -

@interface TGMenuContainerView ()

@end

@implementation TGMenuContainerView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _menuView = [[TGMenuView alloc] init];
        [self addSubview:_menuView];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *result = [super hitTest:point withEvent:event];
    if (result == self || result == nil)
    {
        [self hideMenu];
        
        return nil;
    }
    
    return result;
}

- (void)showMenuFromRect:(CGRect)rect
{
    [self showMenuFromRect:rect animated:true];
}

- (void)showMenuFromRect:(CGRect)rect animated:(bool)animated
{
    _isShowingMenu = true;
    _showingMenuFromRect = rect;
    [_menuView showInView:self fromRect:rect animated:animated];
}

- (void)setFrame:(CGRect)frame
{
    if (!CGSizeEqualToSize(frame.size, self.frame.size))
        [self hideMenu];
    
    [super setFrame:frame];
}

- (void)hideMenu
{
    if (_isShowingMenu)
    {
        _isShowingMenu = false;
        _showingMenuFromRect = CGRectZero;
        
        [_menuView.watcherHandle requestAction:@"menuWillHide" options:nil];
        
        [_menuView hide:^
        {
            [self removeFromSuperview];
        }];
    }
}

@end
