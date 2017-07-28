#import "TGPasscodeEntryKeyboardView.h"

#import <LegacyComponents/LegacyComponents.h>

#import "TGPasscodeButtonView.h"

@interface TGPasscodeEntryKeyboardView ()
{
    id<TGPasscodeBackground> _background;
    
    NSArray *_buttonViews;
}

@end

@implementation TGPasscodeEntryKeyboardView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        [self _generateButtonViews];
    }
    return self;
}

- (NSArray *)_buttonViewInfos
{
    NSArray *infos = @[
        @[@"1", @""],
        @[@"2", @"ABC"],
        @[@"3", @"DEF"],
        @[@"4", @"GHI"],
        @[@"5", @"JKL"],
        @[@"6", @"MNO"],
        @[@"7", @"PQRS"],
        @[@"8", @"TUV"],
        @[@"9", @"WXYZ"],
        @[@"0", @""],
    ];
    return infos;
}

- (void)_generateButtonViews
{
    NSArray *infos = [self _buttonViewInfos];
    
    NSMutableArray *buttonViews = [[NSMutableArray alloc] init];
    for (NSArray *desc in infos)
    {
        TGPasscodeButtonView *buttonView = [[TGPasscodeButtonView alloc] init];
        [buttonView addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
        [buttonView setTitle:desc[0] subtitle:desc[1]];
        [self addSubview:buttonView];
        [buttonViews addObject:buttonView];
    }
    
    _buttonViews = buttonViews;
    [self _layoutButtons];
}

- (void)buttonTouchDown:(TGPasscodeButtonView *)buttonView
{
    NSArray *infos = [self _buttonViewInfos];
    NSUInteger buttonIndex = NSNotFound;
    for (NSUInteger index = 0; index < _buttonViews.count; index++)
    {
        if (buttonView == _buttonViews[index])
        {
            buttonIndex = index;
            break;
        }
    }
    if (buttonIndex != NSNotFound && buttonIndex < infos.count)
    {
        if (_characterEntered)
            _characterEntered(((NSArray *)infos[buttonIndex])[0]);
    }
}

- (void)sizeToFit
{
    CGSize size = CGSizeZero;
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    if (screenSize.width > screenSize.height)
    {
        CGFloat tmp = screenSize.width;
        screenSize.width = screenSize.height;
        screenSize.height = tmp;
    }
    
    if ((int)screenSize.height == 1024 || (int)screenSize.height == 1366)
        size = CGSizeMake(293.0f, 384.0f);
    else if ((int)screenSize.height == 736)
        size = CGSizeMake(281.0f, 345.0f);
    else if ((int)screenSize.height == 667)
        size = CGSizeMake(281.0f, 345.0f);
    else if ((int)screenSize.height == 568)
        size = CGSizeMake(265.0f, 339.0f);
    else
        size = CGSizeMake(265.0f, 339.0f);
    
    self.frame = (CGRect){self.frame.origin, size};
}

- (void)setBackground:(id<TGPasscodeBackground>)background
{
    _background = background;
    for (TGPasscodeButtonView *buttonView in _buttonViews)
    {
        [buttonView setBackground:background];
    }
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    for (TGPasscodeButtonView *buttonView in _buttonViews)
    {
        [buttonView setAbsoluteOffset:CGPointMake(frame.origin.x + buttonView.frame.origin.x, frame.origin.y + buttonView.frame.origin.y)];
    }
}

- (void)_layoutButtons
{
    CGFloat buttonSize = 0.0f;
    CGFloat horizontalSecond = 0.0f;
    CGFloat horizontalThird = 0.0f;
    CGFloat verticalSecond = 0.0f;
    CGFloat verticalThird = 0.0f;
    CGFloat verticalFourth = 0.0f;
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    if (screenSize.width > screenSize.height)
    {
        CGFloat tmp = screenSize.width;
        screenSize.width = screenSize.height;
        screenSize.height = tmp;
    }
    
    if ((int)screenSize.height == 1024 || (int)screenSize.height == 1366)
    {
        buttonSize = 81.0f;
        horizontalSecond = 106.0f;
        horizontalThird = 212.0f;
        verticalSecond = 100.0f + TGRetinaPixel;
        verticalThird = 202.0f;
        verticalFourth = 303.0f;
    }
    else if ((int)screenSize.height == 736)
    {
        buttonSize = 75.0f;
        horizontalSecond = 103.5f;
        horizontalThird = 206.0f;
        verticalSecond = 90.0f;
        verticalThird = 180.0f;
        verticalFourth = 270.0f;
    }
    else if ((int)screenSize.height == 667)
    {
        buttonSize = 75.0f;
        horizontalSecond = 103.5f;
        horizontalThird = 206.0f;
        verticalSecond = 90.0f;
        verticalThird = 180.0f;
        verticalFourth = 270.0f;
    }
    else if ((int)screenSize.height == 568)
    {
        buttonSize = 75.0f;
        horizontalSecond = 95.0f;
        horizontalThird = 190.0f;
        verticalSecond = 88.0f;
        verticalThird = 176.0f;
        verticalFourth = 264.0f;
    }
    else
    {
        buttonSize = 75.0f;
        horizontalSecond = 95.0f;
        horizontalThird = 190.0f;
        verticalSecond = 88.0f;
        verticalThird = 176.0f;
        verticalFourth = 264.0f;
    }
    
    for (NSUInteger i = 0; i < _buttonViews.count; i++)
    {
        CGPoint position = CGPointZero;
        if (i % 3 == 0)
            position.x = 0.0f;
        else if (i % 3 == 1)
            position.x = horizontalSecond;
        else
            position.x = horizontalThird;
        
        if (i / 3 == 0)
            position.y = 0.0f;
        else if (i / 3 == 1)
            position.y = verticalSecond;
        else if (i / 3 == 2)
            position.y = verticalThird;
        else if (i / 3 == 3)
        {
            position.x = horizontalSecond;
            position.y = verticalFourth;
        }
        
        [(TGPasscodeButtonView *)_buttonViews[i] setFrame:CGRectMake(position.x, position.y, buttonSize, buttonSize)];
    }
}

@end
