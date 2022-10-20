#import "TGPhotoEditorCurvesToolView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGImageUtils.h"

typedef enum
{
    TGCurvesSegmentNone,
    TGCurvesSegmentBlacks,
    TGCurvesSegmentShadows,
    TGCurvesSegmentMidtones,
    TGCurvesSegmentHighlights,
    TGCurvesSegmentWhites
} TGCurvesSegment;

@interface TGPhotoEditorCurvesToolView () <UIGestureRecognizerDelegate>
{
    TGCurvesSegment _activeSegment;
    
    UILabel *_blacksLevelLabel;
    UILabel *_shadowsLevelLabel;
    UILabel *_midtonesLevelLabel;
    UILabel *_highlightsLevelLabel;
    UILabel *_whitesLevelLabel;
    
    UIView *_selectionView;
    
    UILongPressGestureRecognizer *_pressGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
    UITapGestureRecognizer *_doubleTapGestureRecognizer;
    
    NSArray *_interpolatedCurveValues;
    CAShapeLayer *_curveLayer;
    bool _appeared;
}

@property (nonatomic, weak) PGCurvesTool *curvesTool;

@end

@implementation TGPhotoEditorCurvesToolView

@synthesize valueChanged = _valueChanged;
@synthesize value = _value;
@synthesize interactionBegan = _interactionBegan;
@synthesize interactionEnded = _interactionEnded;
@synthesize actualAreaSize;
@synthesize isLandscape;
@synthesize toolbarLandscapeSize;

- (instancetype)initWithEditorItem:(id<PGPhotoEditorItem>)__unused editorItem
{
    self = [self initWithFrame:CGRectZero];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        
        _activeSegment = TGCurvesSegmentNone;
        
        _selectionView = [[UIView alloc] initWithFrame:CGRectZero];
        _selectionView.alpha = 0.0f;
        _selectionView.backgroundColor = [UIColor whiteColor];
        _selectionView.userInteractionEnabled = false;
        //[self addSubview:_selectionView];
        
        _blacksLevelLabel = [self _levelLabel];
        _blacksLevelLabel.text = @"0.00";
        [self addSubview:_blacksLevelLabel];
        
        _shadowsLevelLabel = [self _levelLabel];
        _shadowsLevelLabel.text = @"0.00";
        [self addSubview:_shadowsLevelLabel];
        
        _midtonesLevelLabel = [self _levelLabel];
        _midtonesLevelLabel.text = @"0.00";
        [self addSubview:_midtonesLevelLabel];
        
        _highlightsLevelLabel = [self _levelLabel];
        _highlightsLevelLabel.text = @"0.00";
        [self addSubview:_highlightsLevelLabel];
        
        _whitesLevelLabel = [self _levelLabel];
        _whitesLevelLabel.text = @"0.00";
        [self addSubview:_whitesLevelLabel];
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGestureRecognizer.delegate = self;
        [self addGestureRecognizer:_panGestureRecognizer];
        
        _pressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePress:)];
        _pressGestureRecognizer.delegate = self;
        _pressGestureRecognizer.minimumPressDuration = 0.1f;
        [self addGestureRecognizer:_pressGestureRecognizer];
        
        _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
        _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
        [self addGestureRecognizer:_doubleTapGestureRecognizer];
        
        if ([editorItem isKindOfClass:[PGCurvesTool class]])
        {
            PGCurvesTool *curvesTool = (PGCurvesTool *)editorItem;
            self.curvesTool = curvesTool;
            [self setValue:editorItem.value];
        }
    }
    return self;
}

- (UILabel *)_levelLabel
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.backgroundColor = [UIColor clearColor];
    label.font = [TGFont systemFontOfSize:13];
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor colorWithWhite:1.0f alpha:0.75f];
    return label;
}

- (void)setValue:(id)value
{
    if (![value isKindOfClass:[PGCurvesToolValue class]])
        return;
    
    _value = value;
    
    [self updateCurve];
    [self updateValueLabels];
}

- (void)updateCurve
{
    if (CGRectEqualToRect([self _actualArea], CGRectZero))
        return;
    
    PGCurvesToolValue *curvesToolValue = (PGCurvesToolValue *)_value;
    
    PGCurvesValue *curvesValue = nil;
    switch (curvesToolValue.activeType)
    {
        case PGCurvesTypeLuminance:
            curvesValue = curvesToolValue.luminanceCurve;
            break;
            
        case PGCurvesTypeRed:
            curvesValue = curvesToolValue.redCurve;
            break;
            
        case PGCurvesTypeGreen:
            curvesValue = curvesToolValue.greenCurve;
            break;
            
        case PGCurvesTypeBlue:
            curvesValue = curvesToolValue.blueCurve;
            break;
            
        default:
            break;
    }

    NSArray *points = [curvesValue interpolateCurve];
    [self renderCurveWithPoints:points color:[TGPhotoEditorCurvesToolView colorForCurveType:curvesToolValue.activeType] lineWidth:2];
}

- (void)updateValueLabels
{
    PGCurvesToolValue *curvesToolValue = (PGCurvesToolValue *)_value;
    
    PGCurvesValue *curvesValue = nil;
    switch (curvesToolValue.activeType)
    {
        case PGCurvesTypeLuminance:
            curvesValue = curvesToolValue.luminanceCurve;
            break;
            
        case PGCurvesTypeRed:
            curvesValue = curvesToolValue.redCurve;
            break;
            
        case PGCurvesTypeGreen:
            curvesValue = curvesToolValue.greenCurve;
            break;
            
        case PGCurvesTypeBlue:
            curvesValue = curvesToolValue.blueCurve;
            break;
            
        default:
            break;
    }
    
    _blacksLevelLabel.text = [NSString stringWithFormat:@"%0.2f", curvesValue.blacksLevel / 100.0f];
    _shadowsLevelLabel.text = [NSString stringWithFormat:@"%0.2f", curvesValue.shadowsLevel / 100.0f];
    _midtonesLevelLabel.text = [NSString stringWithFormat:@"%0.2f", curvesValue.midtonesLevel / 100.0f];
    _highlightsLevelLabel.text = [NSString stringWithFormat:@"%0.2f", curvesValue.highlightsLevel / 100.0f];
    _whitesLevelLabel.text = [NSString stringWithFormat:@"%0.2f", curvesValue.whitesLevel / 100.0f];
}

+ (UIColor *)colorForCurveType:(PGCurvesType)curveType
{
    switch (curveType)
    {
        case PGCurvesTypeLuminance:
            return [UIColor whiteColor];
            
        case PGCurvesTypeRed:
            return UIColorRGB(0xed3d4c);
            
        case PGCurvesTypeGreen:
            return UIColorRGB(0x10ee9d);
            
        case PGCurvesTypeBlue:
            return UIColorRGB(0x3377fb);
            
        default:
            break;
    }
}

- (bool)buttonPressed:(bool)__unused cancelButton
{
    return true;
}

- (bool)isTracking
{
    return false;
}

- (void)handlePress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
            [self selectSegmentWithPoint:[gestureRecognizer locationInView:gestureRecognizer.view]];
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self unselectSegments];
            break;
            
        default:
            break;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
            [self selectSegmentWithPoint:[gestureRecognizer locationInView:gestureRecognizer.view]];
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            PGCurvesToolValue *newValue = [(PGCurvesToolValue *)_value copy];
            
            CGPoint translation = [gestureRecognizer translationInView:gestureRecognizer.view];
            CGFloat delta = MIN(2, -1 * translation.y / 8.0f);
            
            PGCurvesValue *curveValue = nil;
            switch (newValue.activeType)
            {
                case PGCurvesTypeLuminance:
                    curveValue = newValue.luminanceCurve;
                    break;
                    
                case PGCurvesTypeRed:
                    curveValue = newValue.redCurve;
                    break;
                    
                case PGCurvesTypeGreen:
                    curveValue = newValue.greenCurve;
                    break;
                    
                case PGCurvesTypeBlue:
                    curveValue = newValue.blueCurve;
                    break;
                    
                default:
                    break;
            }
            
            switch (_activeSegment)
            {
                case TGCurvesSegmentBlacks:
                    curveValue.blacksLevel = MAX(0, MIN(100, curveValue.blacksLevel + delta));
                    break;
                    
                case TGCurvesSegmentShadows:
                    curveValue.shadowsLevel = MAX(0, MIN(100, curveValue.shadowsLevel + delta));
                    break;
                    
                case TGCurvesSegmentMidtones:
                    curveValue.midtonesLevel = MAX(0, MIN(100, curveValue.midtonesLevel + delta));
                    break;
                    
                case TGCurvesSegmentHighlights:
                    curveValue.highlightsLevel = MAX(0, MIN(100, curveValue.highlightsLevel + delta));
                    break;
                    
                case TGCurvesSegmentWhites:
                    curveValue.whitesLevel = MAX(0, MIN(100, curveValue.whitesLevel + delta));
                    break;
                    
                default:
                    break;
            }
            
            _value = newValue;
            
            [self updateCurve];
            [self updateValueLabels];
            
            if (self.valueChanged != nil)
                self.valueChanged(newValue, false);
            
            [gestureRecognizer setTranslation:CGPointZero inView:gestureRecognizer.view];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {
            [self unselectSegments];
            
            if (self.interactionEnded != nil)
                self.interactionEnded();
        }
            break;
            
        default:
            break;
    }
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)__unused gestureRecognizer
{
    PGCurvesToolValue *value = [_value copy];
    if (value == nil)
        return;
    
    switch (value.activeType) {
        case PGCurvesTypeLuminance:
            value.luminanceCurve = [PGCurvesValue defaultValue];
            break;
            
        case PGCurvesTypeRed:
            value.redCurve = [PGCurvesValue defaultValue];
            break;
            
        case PGCurvesTypeGreen:
            value.greenCurve = [PGCurvesValue defaultValue];
            break;
            
        case PGCurvesTypeBlue:
            value.blueCurve = [PGCurvesValue defaultValue];
            break;
            
        default:
            break;
    }
    
    _value = value;
    
    [self updateCurve];
    [self updateValueLabels];
    
    self.valueChanged(value, false);
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == _pressGestureRecognizer || gestureRecognizer == _panGestureRecognizer)
    {
        CGPoint location = [gestureRecognizer locationInView:self];
        CGRect actualArea = [self _actualArea];
        
        return CGRectContainsPoint(actualArea, location);
    }
    
    return true;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == _pressGestureRecognizer || otherGestureRecognizer == _pressGestureRecognizer)
        return true;
    
    return false;
}

- (void)selectSegmentWithPoint:(CGPoint)point
{
    if (_activeSegment != TGCurvesSegmentNone)
        return;
    
    CGRect actualArea = [self _actualArea];
    CGFloat segmentWidth = actualArea.size.width / 5.0f;
    
    point = CGPointMake(point.x - actualArea.origin.x, point.y - actualArea.origin.y);
    
    _activeSegment = (TGCurvesSegment)(floor(point.x / segmentWidth) + 1);
    
    [UIView animateWithDuration:0.2f animations:^
    {
        _selectionView.alpha = 0.11f;
    }];

    _selectionView.frame = CGRectMake(actualArea.origin.x + (_activeSegment - 1) * segmentWidth, actualArea.origin.y, segmentWidth, actualArea.size.height);
}

- (void)unselectSegments
{
    if (_activeSegment == TGCurvesSegmentNone)
        return;
    
    _activeSegment = TGCurvesSegmentNone;
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _selectionView.alpha = 0.0f;
    }];
}

- (void)drawRect:(CGRect)__unused rect
{
    CGRect actualArea = [self _actualArea];
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGFloat segmentWidth = actualArea.size.width / 5.0f;
    
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:1.0f alpha:0.6f].CGColor);
    CGContextSetLineWidth(context, 1 - TGRetinaPixel);
    
    for (NSUInteger i = 0; i < 4; i++)
    {
        CGContextMoveToPoint(context, actualArea.origin.x + segmentWidth + i * segmentWidth, actualArea.origin.y);
        CGContextAddLineToPoint(context, actualArea.origin.x + segmentWidth + i * segmentWidth, actualArea.origin.y + actualArea.size.height);
        CGContextStrokePath(context);
    }
    
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:1.0f alpha:0.6f].CGColor);
    CGContextSetLineWidth(context, 1.5f);
    
    CGFloat lengths[] = { 7, 4 };
    CGContextSetLineDash(context, 0.0, lengths, 2);
    
    CGContextMoveToPoint(context, actualArea.origin.x, actualArea.origin.y + actualArea.size.height);
    CGContextAddLineToPoint(context, actualArea.origin.x + actualArea.size.width, actualArea.origin.y );
    CGContextStrokePath(context);
    
    CGContextSetLineDash(context, 0.0, NULL, 0);
}

- (CGRect)_actualArea
{
    return CGRectMake((self.frame.size.width - self.actualAreaSize.width) / 2, (self.frame.size.height - self.actualAreaSize.height) / 2, self.actualAreaSize.width, self.actualAreaSize.height);
}

- (CGPoint)_viewPointWithPoint:(CGPoint)point actualArea:(CGRect)actualArea
{
    return CGPointMake(point.x * actualArea.size.width, (1.0 - point.y) * actualArea.size.height);
}

- (void)renderCurveWithPoints:(NSArray *)points color:(UIColor *)color lineWidth:(CGFloat)lineWidth
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGRect actualArea = [self _actualArea];
    
    [points enumerateObjectsUsingBlock:^(NSValue *value, NSUInteger index, __unused BOOL *stop)
    {
        CGPoint point = [self _viewPointWithPoint:value.CGPointValue actualArea:actualArea];
        
        if (index == 0)
            [path moveToPoint:point];
        else
            [path addLineToPoint:point];
    }];

    if (_curveLayer == nil)
    {
        _curveLayer = [[CAShapeLayer alloc] init];
        _curveLayer.fillColor = [UIColor clearColor].CGColor;
        _curveLayer.lineWidth = lineWidth;
        [_curveLayer setLineCap:kCALineCapRound];
        [self.layer addSublayer:_curveLayer];
    }

    [UIView performWithoutAnimation:^
    {        
        _curveLayer.strokeColor = color.CGColor;
        _curveLayer.path = [path CGPath];
        _curveLayer.frame = CGRectMake(actualArea.origin.x, actualArea.origin.y, actualArea.size.width, actualArea.size.height);
    }];
}

- (void)transitionIn
{
    _appeared = true;
    self.alpha = 0.0f;
    
    [UIView animateWithDuration:0.2f animations:^
    {
        self.alpha = 1.0f;
    }];
}

- (void)layoutSubviews
{
    CGRect actualArea = [self _actualArea];
    CGFloat segmentWidth = actualArea.size.width / 5.0f;
    
    CGFloat bottomOffset = 4.0f;
    
    [_blacksLevelLabel sizeToFit];
    _blacksLevelLabel.frame = CGRectMake(actualArea.origin.x, actualArea.origin.y + actualArea.size.height - ceil(_blacksLevelLabel.frame.size.height) - bottomOffset, segmentWidth, ceil(_blacksLevelLabel.frame.size.height));
    
    [_shadowsLevelLabel sizeToFit];
    _shadowsLevelLabel.frame = CGRectMake(actualArea.origin.x + segmentWidth, actualArea.origin.y + actualArea.size.height - ceil(_shadowsLevelLabel.frame.size.height) - bottomOffset, segmentWidth, ceil(_shadowsLevelLabel.frame.size.height));
    
    [_midtonesLevelLabel sizeToFit];
    _midtonesLevelLabel.frame = CGRectMake(actualArea.origin.x + segmentWidth * 2, actualArea.origin.y + actualArea.size.height - ceil(_midtonesLevelLabel.frame.size.height) - bottomOffset, segmentWidth, ceil(_midtonesLevelLabel.frame.size.height));
    
    [_highlightsLevelLabel sizeToFit];
    _highlightsLevelLabel.frame = CGRectMake(actualArea.origin.x + segmentWidth * 3, actualArea.origin.y + actualArea.size.height - ceil(_highlightsLevelLabel.frame.size.height) - bottomOffset, segmentWidth, ceil(_highlightsLevelLabel.frame.size.height));
    
    [_whitesLevelLabel sizeToFit];
    _whitesLevelLabel.frame = CGRectMake(actualArea.origin.x + segmentWidth * 4, actualArea.origin.y + actualArea.size.height - ceil(_whitesLevelLabel.frame.size.height) - bottomOffset, segmentWidth, ceil(_whitesLevelLabel.frame.size.height));
    
    _curveLayer.frame = CGRectMake(actualArea.origin.x, actualArea.origin.y, actualArea.size.width, actualArea.size.height);
    
    [self updateCurve];
    
    [self updateValueLabels];
    if (!_appeared)
        [self transitionIn];
}

@end
