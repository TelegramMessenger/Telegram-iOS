#import "TGPhotoEditorCurvesHistogramView.h"

#import "LegacyComponentsInternal.h"

#import <SSignalKit/SSignalKit.h>

#import "PGCurvesTool.h"
#import "PGPhotoToolComposer.h"
#import "PGPhotoHistogram.h"

#import <LegacyComponents/TGModernButton.h>
#import "TGPhotoEditorInterfaceAssets.h"
#import "TGHistogramView.h"

#import "TGPhotoEditorTabController.h"
#import "TGPhotoEditorToolButtonsView.h"

@interface TGPhotoEditorCurvesHistogramView ()
{
    TGModernButton *_rgbButton;
    TGModernButton *_redButton;
    TGModernButton *_greenButton;
    TGModernButton *_blueButton;
    TGHistogramView *_histogramView;
    
    SMetaDisposable *_histogramDisposable;
    PGPhotoHistogram *_histogram;
    
    bool _appeared;
}
@end

@implementation TGPhotoEditorCurvesHistogramView

@synthesize valueChanged = _valueChanged;
@synthesize value = _value;
@synthesize interactionEnded = _interactionEnded;
@synthesize actualAreaSize;
@synthesize isLandscape = _isLandscape;
@synthesize toolbarLandscapeSize;

- (instancetype)initWithEditorItem:(id<PGPhotoEditorItem>)editorItem
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _rgbButton = [self _modeButtonWithTitle:TGLocalized(@"PhotoEditor.CurvesAll")];
        _rgbButton.selected = true;
        _rgbButton.tag = PGCurvesTypeLuminance;
        [self addSubview:_rgbButton];
        
        _redButton = [self _modeButtonWithTitle:TGLocalized(@"PhotoEditor.CurvesRed")];
        _redButton.tag = PGCurvesTypeRed;
        [self addSubview:_redButton];
    
        _greenButton = [self _modeButtonWithTitle:TGLocalized(@"PhotoEditor.CurvesGreen")];
        _greenButton.tag = PGCurvesTypeGreen;
        [self addSubview:_greenButton];
        
        _blueButton = [self _modeButtonWithTitle:TGLocalized(@"PhotoEditor.CurvesBlue")];
        _blueButton.tag = PGCurvesTypeBlue;
        [self addSubview:_blueButton];
        
        _histogramView = [[TGHistogramView alloc] initWithFrame:CGRectZero];
        [self addSubview:_histogramView];
        
        if ([editorItem isKindOfClass:[PGCurvesTool class]])
            [self setValue:editorItem.value];
        
        _histogramDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_histogramDisposable dispose];
}

- (void)setIsLandscape:(bool)isLandscape
{
    _isLandscape = isLandscape;
    _histogramView.isLandscape = isLandscape;
    
    [self layoutHistogramView];
}

- (CGSize)histogramViewSize
{
    CGSize screenSize = TGScreenSize();
    CGFloat portraitHeight = TGPhotoEditorPanelSize + TGPhotoEditorToolbarSize - TGPhotoEditorToolButtonsViewSize;
    if (self.isLandscape)
        return CGSizeMake(TGPhotoEditorPanelSize - 34, screenSize.width);
    else
        return CGSizeMake(screenSize.width, portraitHeight - 34);
}

- (void)layoutHistogramView
{
    CGSize histogramViewSize = [self histogramViewSize];
    _histogramView.frame = CGRectMake(0, 0, histogramViewSize.width, histogramViewSize.height);
}

- (TGModernButton *)_modeButtonWithTitle:(NSString *)title
{
    TGModernButton *button = [[TGModernButton alloc] initWithFrame:CGRectZero];
    
    button = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 80, 20)];
    button.backgroundColor = [UIColor clearColor];
    button.titleLabel.font = [TGPhotoEditorInterfaceAssets editorItemTitleFont];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColorRGB(0x808080) forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected | UIControlStateHighlighted];
    [button addTarget:self action:@selector(modeButtonPressed:) forControlEvents:UIControlEventTouchDown];
    
    return button;
}

- (void)modeButtonPressed:(TGModernButton *)sender
{
    for (TGModernButton *button in self.subviews)
    {
        if (![button isKindOfClass:[TGModernButton class]])
            continue;
        
        button.selected = (button == sender);
    }

    PGCurvesToolValue *value = [(PGCurvesToolValue *)self.value copy];
    if (value.activeType != sender.tag)
    {
        value.activeType = (PGCurvesType)sender.tag;
        
        _value = value;
        
        self.valueChanged(value, false);
        
        [self updateHistogram];
    }
}

- (bool)isTracking
{
    return false;
}

- (bool)buttonPressed:(bool)__unused cancelButton
{
    return true;
}

- (void)layoutSubviews
{
    UIInterfaceOrientation orientation = [[LegacyComponentsGlobals provider] applicationStatusBarOrientation];
    CGSize histogramViewSize = [self histogramViewSize];
    
    if (!self.isLandscape)
    {
        _rgbButton.frame = CGRectMake(floor(self.frame.size.width / 5 - _rgbButton.frame.size.width / 2), 10, _rgbButton.frame.size.width, _rgbButton.frame.size.height);
        _redButton.frame = CGRectMake(floor(self.frame.size.width / 5 * 2 - _redButton.frame.size.width / 2), 10, _redButton.frame.size.width, _redButton.frame.size.height);
        _greenButton.frame = CGRectMake(floor(self.frame.size.width / 5 * 3 - _greenButton.frame.size.width / 2), 10, _greenButton.frame.size.width, _greenButton.frame.size.height);
        _blueButton.frame = CGRectMake(floor(self.frame.size.width / 5 * 4 - _blueButton.frame.size.width / 2), 10, _blueButton.frame.size.width, _blueButton.frame.size.height);
        
        _histogramView.frame = CGRectMake(0, 34, histogramViewSize.width, histogramViewSize.height);
    }
    else
    {
        [UIView performWithoutAnimation:^
        {
            if (orientation == UIInterfaceOrientationLandscapeLeft)
            {
                CGAffineTransform transform = CGAffineTransformMakeRotation(M_PI_2);
                _rgbButton.transform = transform;
                _redButton.transform = transform;
                _greenButton.transform = transform;
                _blueButton.transform = transform;
                _histogramView.transform = transform;
                
                _rgbButton.frame = CGRectMake(self.frame.size.width - _rgbButton.frame.size.width - 10, floor(self.frame.size.height / 5 - _rgbButton.frame.size.height / 2), _rgbButton.frame.size.width, _rgbButton.frame.size.height);
                _redButton.frame = CGRectMake(self.frame.size.width - _redButton.frame.size.width - 10, floor(self.frame.size.height / 5 * 2 - _redButton.frame.size.height / 2), _redButton.frame.size.width, _redButton.frame.size.height);
                _greenButton.frame = CGRectMake(self.frame.size.width - _blueButton.frame.size.width - 10, floor(self.frame.size.height / 5 * 3 - _greenButton.frame.size.height / 2), _greenButton.frame.size.width, _greenButton.frame.size.height);
                _blueButton.frame = CGRectMake(self.frame.size.width - _blueButton.frame.size.width - 10, floor(self.frame.size.height / 5 * 4 - _blueButton.frame.size.height / 2), _blueButton.frame.size.width, _blueButton.frame.size.height);
                _histogramView.frame = CGRectMake(0, 0, histogramViewSize.width, histogramViewSize.height);
            }
            else if (orientation == UIInterfaceOrientationLandscapeRight)
            {
                CGAffineTransform transform = CGAffineTransformMakeRotation(-M_PI_2);
                _rgbButton.transform = transform;
                _redButton.transform = transform;
                _greenButton.transform = transform;
                _blueButton.transform = transform;
                _histogramView.transform = transform;
                
                _rgbButton.frame = CGRectMake(10, floor(self.frame.size.height / 5 * 4 - _rgbButton.frame.size.height / 2), _rgbButton.frame.size.width, _rgbButton.frame.size.height);
                _redButton.frame = CGRectMake(10, floor(self.frame.size.height / 5 * 3 - _redButton.frame.size.height / 2), _redButton.frame.size.width, _redButton.frame.size.height);
                _greenButton.frame = CGRectMake(10, floor(self.frame.size.height / 5 * 2 - _greenButton.frame.size.height / 2), _greenButton.frame.size.width, _greenButton.frame.size.height);
                _blueButton.frame = CGRectMake(10, floor(self.frame.size.height / 5 - _blueButton.frame.size.height / 2), _blueButton.frame.size.width, _blueButton.frame.size.height);
                _histogramView.frame = CGRectMake(34, 0, histogramViewSize.width, histogramViewSize.height);
            }
        }];
    }
    
    if (!_appeared)
    {
        _appeared = true;
        [self updateHistogram];
    }
}

- (void)updateHistogram
{
    PGCurvesToolValue *value = (PGCurvesToolValue *)self.value;
    [_histogramView setHistogram:_histogram type:value.activeType animated:true];
}

- (void)setHistogramSignal:(SSignal *)signal
{
    __weak TGPhotoEditorCurvesHistogramView *weakSelf = self;
    [_histogramDisposable setDisposable:[[signal deliverOn:[SQueue mainQueue]] startWithNext:^(PGPhotoHistogram *next)
    {
        __strong TGPhotoEditorCurvesHistogramView *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_histogram = next;
            [strongSelf updateHistogram];
        }
    }]];
}

@synthesize interactionBegan;

@end
