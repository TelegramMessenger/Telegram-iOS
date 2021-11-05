#import "TGPhotoEditorSliderView.h"

#import "LegacyComponentsInternal.h"

#import "TGPhotoEditorInterfaceAssets.h"

const CGFloat TGPhotoEditorSliderViewLineSize = 3.0f;
const CGFloat TGPhotoEditorSliderViewMargin = 15.0f;
const CGFloat TGPhotoEditorSliderViewInternalMargin = 7.0f;

@interface TGPhotoEditorSliderView () <UIGestureRecognizerDelegate>
{
    CGFloat _knobTouchStart;
    CGFloat _knobTouchCenterStart;
    CGFloat _knobDragCenter;
    
    UIPanGestureRecognizer *_panGestureRecognizer;
    UITapGestureRecognizer *_tapGestureRecognizer;
    UITapGestureRecognizer *_doubleTapGestureRecognizer;
    
    UIColor *_backColor;
    UIColor *_trackColor;
    UIColor *_startColor;
    
    bool _startHidden;
    
    UISelectionFeedbackGenerator *_feedbackGenerator;
}
@end

@implementation TGPhotoEditorSliderView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _minimumValue = 0.0f;
        _maximumValue = 1.0f;
        _startValue = 0.0f;
        _value = _startValue;
        _dotSize = 10.5f;
        _minimumUndottedValue = -1;
        
        _lineSize = TGPhotoEditorSliderViewLineSize;
        _knobPadding = TGPhotoEditorSliderViewInternalMargin;
        
        _backColor = [TGPhotoEditorInterfaceAssets sliderBackColor];
        _trackColor = [TGPhotoEditorInterfaceAssets sliderTrackColor];
        _startColor = [TGPhotoEditorInterfaceAssets sliderTrackColor];
        
        static UIImage *knobViewImage = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(21.0f, 21.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetShadowWithColor(context, CGSizeMake(0, 0.5f), 1.5f, [UIColor colorWithWhite:0.0f alpha:0.5f].CGColor);
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(2.0f, 2.0f, 17.0f, 17.0f));
            knobViewImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _knobView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _knobView.image = knobViewImage;
        [self addSubview:_knobView];
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGestureRecognizer.enabled = false;
        [self addGestureRecognizer:_panGestureRecognizer];
        
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        _tapGestureRecognizer.enabled = false;
        [self addGestureRecognizer:_tapGestureRecognizer];
        
        _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
        _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
        [self addGestureRecognizer:_doubleTapGestureRecognizer];
        
        if (iosMajorVersion() >= 10)
            _feedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];
    }
    return self;
}

#pragma mark -

- (void)setPositionsCount:(NSInteger)positionsCount
{
    _positionsCount = positionsCount;
    _tapGestureRecognizer.enabled = !_disableSnapToPositions && _positionsCount > 1;
    _doubleTapGestureRecognizer.enabled = !_tapGestureRecognizer.enabled;
}

- (void)drawRectangle:(CGRect)rect cornerRadius:(CGFloat)cornerRadius context:(CGContextRef)context
{
    if (cornerRadius > FLT_EPSILON)
    {
        CGContextAddPath(context, [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:cornerRadius].CGPath);
        CGContextClosePath(context);
        CGContextFillPath(context);
    }
    else
    {
        CGContextFillRect(context, rect);
    }
}

- (void)drawRect:(CGRect)__unused rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGFloat margin = TGPhotoEditorSliderViewInternalMargin;
    CGFloat visualMargin = _positionsCount > 1 ? margin : 2.0f;
    CGFloat totalLength = self.frame.size.width - margin * 2;
    CGFloat visualTotalLength = self.frame.size.width - 2 * (_positionsCount > 1 ? margin : visualMargin);
    CGFloat sideLength = self.frame.size.height;
    bool vertical = false;
    if (self.frame.size.width < self.frame.size.height)
    {
        totalLength = self.frame.size.height - margin * 2;
        visualTotalLength = self.frame.size.height - 2 * (_positionsCount > 1 ? margin : visualMargin);
        sideLength = self.frame.size.width;
        vertical = true;
    }
    
    CGFloat knobPosition = _knobPadding + (_knobView.highlighted ? _knobDragCenter : [self centerPositionForValue:_value totalLength:totalLength knobSize:_knobView.image.size.width vertical:vertical]);
    knobPosition = MAX(_knobPadding, MIN(knobPosition, _knobPadding + totalLength));
    
    CGFloat startPosition = visualMargin + visualTotalLength / (_maximumValue - _minimumValue) * (ABS(_minimumValue) + _startValue);
    if (vertical)
        startPosition = 2 * visualMargin + visualTotalLength - startPosition;
    
    CGFloat endPosition = visualMargin + visualTotalLength / (_maximumValue - _minimumValue) * (ABS(_minimumValue) + 1.0);
    if (vertical)
        endPosition = 2 * visualMargin + visualTotalLength - endPosition;
    
    CGFloat origin = startPosition;
    CGFloat track = knobPosition - startPosition;
    if (track < 0)
    {
        track = fabs(track);
        origin -= track;
    }
    
    CGRect backFrame = CGRectMake(visualMargin, (sideLength - _lineSize) / 2, visualTotalLength, _lineSize);
    CGRect trackFrame = CGRectMake(origin, (sideLength - _lineSize) / 2, track, _lineSize);
    CGRect startFrame = CGRectMake(startPosition - 4 / 2, (sideLength - 12) / 2, 4, 12);
    CGRect endFrame = CGRectMake(endPosition - 4 / 2, (sideLength - 12) / 2, 4, 12);
    CGRect knobFrame = CGRectMake(knobPosition - _knobView.image.size.width / 2, (sideLength - _knobView.image.size.height) / 2, _knobView.image.size.width, _knobView.image.size.height);
    if (vertical)
    {
        backFrame = CGRectMake(backFrame.origin.y, backFrame.origin.x, backFrame.size.height, backFrame.size.width);
        trackFrame = CGRectMake(trackFrame.origin.y, trackFrame.origin.x, trackFrame.size.height, trackFrame.size.width);
        startFrame = CGRectMake(startFrame.origin.y, startFrame.origin.x, startFrame.size.height, startFrame.size.width);
        endFrame = CGRectMake(endFrame.origin.y, endFrame.origin.x, endFrame.size.height, endFrame.size.width);
        knobFrame = CGRectMake(knobFrame.origin.y, knobFrame.origin.x, knobFrame.size.width, knobFrame.size.height);
    }
    
    if (_markValue > FLT_EPSILON)
    {
        CGContextSetFillColorWithColor(context, _backColor.CGColor);
        [self drawRectangle:backFrame cornerRadius:0.0f context:context];
    }
    
    if (_bordered)
    {
        CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 0.6f).CGColor);
        [self drawRectangle:CGRectInset(backFrame, -1.0f, -1.0f) cornerRadius:self.trackCornerRadius * 2.0f context:context];
        if (!_startHidden)
            [self drawRectangle:CGRectInset(startFrame, -1.0f, -1.0f) cornerRadius:self.trackCornerRadius * 2.0f context:context];
        
        CGContextSetBlendMode(context, kCGBlendModeCopy);
    }

    CGContextSetFillColorWithColor(context, _backColor.CGColor);
    [self drawRectangle:backFrame cornerRadius:self.trackCornerRadius context:context];

    CGContextSetBlendMode(context, kCGBlendModeNormal);

    CGContextSetFillColorWithColor(context, _trackColor.CGColor);
    [self drawRectangle:trackFrame cornerRadius:self.trackCornerRadius context:context];
    
    if (!_startHidden || self.displayEdges)
    {
        bool highlighted = CGRectGetMidX(startFrame) < CGRectGetMaxX(trackFrame);
        if (vertical)
            highlighted = CGRectGetMidY(startFrame) > CGRectGetMinY(trackFrame);
        highlighted = highlighted && self.displayEdges;
        
        CGContextSetFillColorWithColor(context, highlighted ? _trackColor.CGColor : _startColor.CGColor);
        [self drawRectangle:startFrame cornerRadius:self.trackCornerRadius context:context];
    }
    
    if (self.displayEdges) {
        CGContextSetFillColorWithColor(context, _startColor.CGColor);
        [self drawRectangle:endFrame cornerRadius:self.trackCornerRadius context:context];
    }
    
    if (_bordered)
    {
        CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 0.6f).CGColor);
        CGContextFillEllipseInRect(context, CGRectInset(knobFrame, 1.0f, 1.0f));
    }
    
    if (self.positionsCount > 1)
    {
        for (NSInteger i = 0; i < self.positionsCount; i++)
        {
            if (self.useLinesForPositions) {
                CGSize lineSize = CGSizeMake(4.0, 12.0);
                CGRect lineRect = CGRectMake(margin - lineSize.width / 2.0f + totalLength / (self.positionsCount - 1) * i, (sideLength - lineSize.height) / 2, lineSize.width, lineSize.height);
                if (vertical)
                    lineRect = CGRectMake(lineRect.origin.y, lineRect.origin.x, lineRect.size.height, lineRect.size.width);
                
                bool highlighted = CGRectGetMidX(lineRect) < CGRectGetMaxX(trackFrame);
                if (vertical)
                    highlighted = CGRectGetMidY(lineRect) > CGRectGetMinY(trackFrame);
                
                CGContextSetFillColorWithColor(context, highlighted ? _trackColor.CGColor : _backColor.CGColor);
                [self drawRectangle:lineRect cornerRadius:self.trackCornerRadius context:context];
            } else {
                if ([self.backgroundColor isEqual:[UIColor clearColor]])
                {
                    CGContextSetBlendMode(context, kCGBlendModeClear);
                    CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
                }
                else
                {
                    CGContextSetFillColorWithColor(context, self.backgroundColor.CGColor);
                }
                
                CGFloat inset = 1.5f;
                CGFloat outerSize = _dotSize + inset * 2.0f;
                CGRect dotRect = CGRectMake(margin - outerSize / 2.0f + totalLength / (self.positionsCount - 1) * i, (sideLength - outerSize) / 2, outerSize, outerSize);
                if (vertical)
                    dotRect = CGRectMake(dotRect.origin.y, dotRect.origin.x, dotRect.size.height, dotRect.size.width);
                
                CGContextFillEllipseInRect(context, dotRect);
                
                dotRect = CGRectInset(dotRect, inset, inset);
            
                CGContextSetBlendMode(context, kCGBlendModeNormal);
                bool highlighted = CGRectGetMidX(dotRect) < CGRectGetMaxX(trackFrame);
                if (vertical)
                    highlighted = CGRectGetMidY(dotRect) > CGRectGetMinY(trackFrame);
                
                CGContextSetFillColorWithColor(context, highlighted ? _trackColor.CGColor : _backColor.CGColor);
                CGContextFillEllipseInRect(context, dotRect);
            }
        }
    }
}

#pragma mark -

- (void)setLineSize:(CGFloat)lineSize
{
    _lineSize = lineSize;
    [self setNeedsLayout];
}

- (UIColor *)backColor
{
    return _backColor;
}

- (void)setBackColor:(UIColor *)backColor
{
    _backColor = backColor;
    [self setNeedsDisplay];
}

- (UIColor *)trackColor
{
    return _trackColor;
}

- (void)setTrackColor:(UIColor *)trackColor
{
    if (_trackColor == nil || ![_trackColor isEqual:trackColor]) {
        _trackColor = trackColor;
        [self setNeedsDisplay];
    }
}

- (UIColor *)startColor
{
    return _startColor;
}

- (void)setStartColor:(UIColor *)startColor
{
    _startColor = startColor;
    [self setNeedsDisplay];
}

- (UIImage *)knobImage
{
    return _knobView.image;
}

- (void)setKnobImage:(UIImage *)knobImage
{
    _knobView.image = knobImage;
    [self setNeedsLayout];
}

- (void)setBordered:(bool)bordered
{
    _bordered = bordered;
    [self setNeedsDisplay];
}

- (void)setMinimumUndottedValue:(int)minimumUndottedValue {
    if (_minimumUndottedValue != minimumUndottedValue) {
        _minimumUndottedValue = minimumUndottedValue;
        [self setNeedsDisplay];
    }
}

#pragma mark - Properties

- (BOOL)isTracking
{
    return _knobView.highlighted;
}

- (void)setValue:(CGFloat)value
{
    [self setValue:value animated:NO];
}

- (void)setValue:(CGFloat)value animated:(BOOL)__unused animated
{
    _value = MIN(MAX(value, _minimumValue), _maximumValue);
    [self setNeedsLayout];
}

- (void)setStartValue:(CGFloat)startValue
{
    _startValue = startValue;
    if (ABS(_startValue - _minimumValue) < FLT_EPSILON)
        _startHidden = true;

    [self setNeedsLayout];
    [self setNeedsDisplay];
}

- (void)setDotSize:(CGFloat)dotSize
{
    _dotSize = dotSize;
    [self setNeedsDisplay];
}

- (void)layoutSubviews
{
    if (CGRectIsEmpty(self.frame))
        return;
    
    CGFloat margin = TGPhotoEditorSliderViewInternalMargin;
    CGFloat totalLength = self.frame.size.width - margin * 2;
    CGFloat sideLength = self.frame.size.height;
    bool vertical = false;
    if (self.frame.size.width < self.frame.size.height)
    {
        totalLength = self.frame.size.height - margin * 2;
        sideLength = self.frame.size.width;
        vertical = true;
    }
    
    CGFloat knobPosition = _knobPadding + (_knobView.highlighted && self.positionsCount < 2 ? _knobDragCenter : [self centerPositionForValue:_value totalLength:totalLength knobSize:_knobView.image.size.width vertical:vertical]);
    knobPosition = MAX(_knobPadding, MIN(knobPosition, _knobPadding + totalLength));
    
    CGRect knobViewFrame = CGRectMake(knobPosition - _knobView.image.size.width / 2, (sideLength - _knobView.image.size.height) / 2, _knobView.image.size.width, _knobView.image.size.height);
    
    if (self.frame.size.width > self.frame.size.height)
        _knobView.frame = knobViewFrame;
    else
        _knobView.frame = CGRectMake(knobViewFrame.origin.y, knobViewFrame.origin.x, knobViewFrame.size.width, knobViewFrame.size.height);
    
    [self setNeedsDisplay];
}

#pragma mark -

- (CGFloat)centerPositionForValue:(CGFloat)value totalLength:(CGFloat)totalLength knobSize:(CGFloat)knobSize vertical:(bool)vertical
{
    if (_minimumValue < 0)
    {
        CGFloat knob = knobSize;
        if ((NSInteger)value == 0)
        {
            return totalLength / 2;
        }
        else
        {
            CGFloat edgeValue = (value > 0 ? _maximumValue : _minimumValue);
            if ((value < 0 && vertical) || (value > 0 && !vertical))
                return ((totalLength + knob) / 2) + ((totalLength - knob) / 2) * ABS(value / edgeValue);
            else
                return ((totalLength - knob) / 2) * ABS((edgeValue - _value) / edgeValue);
        }
    }

    CGFloat position = totalLength / (_maximumValue - _minimumValue) * (ABS(_minimumValue) + value);
    if (vertical)
        position = totalLength - position;
    
    return position;
}

- (CGFloat)valueForCenterPosition:(CGFloat)position totalLength:(CGFloat)totalLength knobSize:(CGFloat)knobSize vertical:(bool)vertical
{
    CGFloat value = 0;
    if (_minimumValue < 0)
    {
        CGFloat knob = knobSize;
        if (position < (totalLength - knob) / 2)
        {
            CGFloat edgeValue = _minimumValue;
            if (vertical)
            {
                edgeValue = _maximumValue;
                position *= -1;
            }

            value = edgeValue + position / ((totalLength - knob) / 2) * ABS(edgeValue);
        }
        else if (position >= (totalLength - knob) / 2 && position <= (totalLength + knob) / 2)
        {
            value = 0;
        }
        else if (position > (totalLength + knob) / 2)
        {
            CGFloat edgeValue = (vertical ? _minimumValue : _maximumValue);
            value = (position - ((totalLength + knob) / 2)) / ((totalLength - knob) / 2) * edgeValue;
        }
    }
    else
    {
        value = _minimumValue + (!vertical ? position : (totalLength - position)) / totalLength * (_maximumValue - _minimumValue);
    }
    
    return MIN(MAX(value, _minimumValue), _maximumValue);
}

- (void)setEnablePanHandling:(bool)enablePanHandling {
    _enablePanHandling = enablePanHandling;
    _panGestureRecognizer.enabled = enablePanHandling;
}

#pragma mark - Touch Handling

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        [self handleBeginTracking:[gestureRecognizer locationInView:self]];
    } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        [self handleContinueTracking:[gestureRecognizer locationInView:self]];
    } else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [self handleEndTracking];
    } else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
        [self handleCancelTracking];
    }
}

- (void)handleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    CGPoint touchLocation = [gestureRecognizer locationInView:self];
    CGFloat totalLength = self.frame.size.width;
    CGFloat location = touchLocation.x;
    
    if (self.frame.size.width < self.frame.size.height)
    {
        totalLength = self.frame.size.height;
        location = touchLocation.y;
    }
    
    CGFloat position = ((location / totalLength) * (self.positionsCount - 1));
    CGFloat previousPosition = MAX(0, floor(position));
    CGFloat nextPosition = MIN(self.positionsCount - 1, ceil(position));
    
    bool changed = false;
    if (fabs(position - previousPosition) < 0.3f)
    {
        [self setValue:previousPosition];
        changed = true;
    }
    else if (fabs(position - nextPosition) < 0.3f)
    {
        [self setValue:nextPosition];
        changed = true;
    }
    
    if (changed)
    {
        if (self.interactionBegan != nil)
            self.interactionBegan();
        
        [self setNeedsLayout];
        [self sendActionsForControlEvents:UIControlEventValueChanged];
        
        if (self.interactionEnded != nil)
            self.interactionEnded();
        
        [_feedbackGenerator selectionChanged];
        [_feedbackGenerator prepare];
    }
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)__unused gestureRecognizer
{
    if (self.reset != nil)
        self.reset();
}

- (void)maybeCancelParentViewScrolling:(UIView *)parentView depth:(int32_t)depth
{
    if (depth > 5)
        return;
    
    if ([parentView isKindOfClass:[UIScrollView class]])
    {
        ((UIScrollView *)parentView).scrollEnabled = false;
        ((UIScrollView *)parentView).scrollEnabled = true;
    }
    else if (parentView.superview != nil)
    {
        [self maybeCancelParentViewScrolling:parentView.superview depth:depth++];
    }
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)__unused event
{
    if (!_enablePanHandling) {
        CGPoint touchLocation = [touch locationInView:self];
        [self handleBeginTracking:touchLocation];
    }
    return true;
}

- (void)handleBeginTracking:(CGPoint)touchLocation {
    _knobView.highlighted = true;
    
    if (self.frame.size.width > self.frame.size.height)
    {
        _knobTouchCenterStart = _knobView.center.x;
        _knobTouchStart = _knobDragCenter = touchLocation.x;
    }
    else
    {
        _knobTouchCenterStart = _knobView.center.y;
        _knobTouchStart = _knobDragCenter = touchLocation.y;
    }
    
    _knobStartedDragging = false;
    
    [_feedbackGenerator prepare];
    
    [self maybeCancelParentViewScrolling:self.superview depth:0];
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)__unused event
{
    if (!_enablePanHandling) {
        CGPoint touchLocation = [touch locationInView:self];
        [self handleContinueTracking:touchLocation];
    }
    return true;
}

- (BOOL)handleContinueTracking:(CGPoint)touchLocation
{
    if (fabs(touchLocation.x - _knobTouchStart) > 1.0f && !_knobStartedDragging)
    {
        _knobStartedDragging = true;
        
        if (self.interactionBegan != nil)
            self.interactionBegan();
    }
    
    _knobDragCenter = _knobTouchCenterStart - _knobTouchStart - _knobPadding;
    
    CGFloat totalLength = self.frame.size.width;
    bool vertical = false;
    
    if (self.frame.size.width > self.frame.size.height)
    {
        _knobDragCenter += touchLocation.x;
    }
    else
    {
        vertical = true;
        totalLength = self.frame.size.height;
        _knobDragCenter += touchLocation.y;
    }
    totalLength -= _knobPadding * 2;
    
    CGFloat previousValue = self.value;
    if (self.positionsCount > 1 && !self.disableSnapToPositions)
    {
        NSInteger position = (NSInteger)round((_knobDragCenter / totalLength) * (self.positionsCount - 1));
        _knobDragCenter = position * totalLength / (self.positionsCount - 1);
    }
    
    [self setValue:[self valueForCenterPosition:_knobDragCenter totalLength:totalLength knobSize:_knobView.image.size.width vertical:vertical]];
    if (previousValue != self.value && !self.disableSnapToPositions && (self.positionsCount > 1 || self.value == self.minimumValue || self.value == self.maximumValue || (self.minimumValue != self.startValue && self.value == self.startValue)))
    {
        [_feedbackGenerator selectionChanged];
        [_feedbackGenerator prepare];
    }
    
    [self setNeedsLayout];
    if (!_limitValueChangedToLatestState) {
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
    
    return true;
}

- (void)endTrackingWithTouch:(UITouch *)__unused touch withEvent:(UIEvent *)__unused event
{
    if (!_enablePanHandling) {
        [self handleEndTracking];
    }
}

- (void)handleEndTracking
{
    _knobView.highlighted = false;
    
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    [self setNeedsLayout];
    
    if (self.interactionEnded != nil)
        self.interactionEnded();
}

- (void)cancelTrackingWithEvent:(UIEvent *)__unused event
{
    if (!_enablePanHandling) {
        [self handleCancelTracking];
    }
}

- (void)handleCancelTracking
{
    _knobView.highlighted = false;
    
    [self setNeedsLayout];
    
    if (self.interactionEnded != nil)
        self.interactionEnded();
}

@end
