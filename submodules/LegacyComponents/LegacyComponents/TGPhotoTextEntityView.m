#import "TGPhotoTextEntityView.h"

#import "TGColor.h"

#import <LegacyComponents/TGPaintUtils.h>

const CGFloat TGPhotoTextSelectionViewHandleSide = 30.0f;

@interface TGPhotoTextView ()

@end

@interface TGPhotoTextSelectionView () <UIGestureRecognizerDelegate>
{
    UIView *_leftHandle;
    UIView *_rightHandle;
    
    UIPanGestureRecognizer *_leftGestureRecognizer;
    UIPanGestureRecognizer *_rightGestureRecognizer;
}
@end


@interface TGPhotoTextLayoutManager : NSLayoutManager

@property (nonatomic, strong) UIColor *strokeColor;
@property (nonatomic, assign) CGFloat strokeWidth;
@property (nonatomic, assign) CGPoint strokeOffset;

@end


@interface TGPhotoTextEntityView () <UITextViewDelegate>
{
    TGPaintSwatch *_swatch;
    TGPhotoPaintFont *_font;
    CGFloat _baseFontSize;
    CGFloat _maxWidth;
    bool _stroke;
    
    TGPhotoTextView *_textView;
}
@end

@implementation TGPhotoTextEntityView

- (instancetype)initWithEntity:(TGPhotoPaintTextEntity *)entity
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _entityUUID = entity.uuid;
        _baseFontSize = entity.baseFontSize;
        _font = entity.font;
        _maxWidth = entity.maxWidth;
        
        _textView = [[TGPhotoTextView alloc] initWithFrame:CGRectZero];
        _textView.clipsToBounds = false;
        _textView.backgroundColor = [UIColor clearColor];
        _textView.delegate = self;
        _textView.text = entity.text;
        _textView.textColor = entity.swatch.color;
        _textView.editable = false;
        _textView.selectable = false;
        _textView.contentInset = UIEdgeInsetsZero;
        _textView.showsHorizontalScrollIndicator = false;
        _textView.showsVerticalScrollIndicator = false;
        _textView.textContainerInset = UIEdgeInsetsZero;
        _textView.scrollsToTop = false;
        _textView.scrollEnabled = false;
        _textView.textContainerInset = UIEdgeInsetsZero;
        _textView.textAlignment = NSTextAlignmentCenter;
        _textView.minimumZoomScale = 1.0f;
        _textView.maximumZoomScale = 1.0f;
        _textView.keyboardAppearance = UIKeyboardAppearanceDark;
        _textView.autocorrectionType = UITextAutocorrectionTypeNo;
        _textView.spellCheckingType = UITextSpellCheckingTypeNo;
        _textView.font = [UIFont boldSystemFontOfSize:_baseFontSize];
        
        [self setSwatch:entity.swatch];
        [self setStroke:entity.stroke];
    
        [self addSubview:_textView];
    }
    return self;
}

- (bool)isEmpty
{
    return [_textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0;
}

- (TGPhotoPaintTextEntity *)entity
{
    TGPhotoPaintTextEntity *entity = [[TGPhotoPaintTextEntity alloc] initWithText:_textView.text font:_font swatch:_swatch baseFontSize:_baseFontSize maxWidth:_maxWidth stroke:_stroke];
    entity.uuid = _entityUUID;
    entity.angle = self.angle;
    entity.scale = self.scale;
    entity.position = self.center;
    
    return entity;
}

- (bool)isEditing
{
    return _textView.isFirstResponder;
}

- (void)beginEditing
{
    if (self.beganEditing != nil)
        self.beganEditing(self);
    
    _textView.editable = true;
    _textView.selectable = true;
    
    [_textView.window makeKeyWindow];
    [_textView becomeFirstResponder];
}

- (void)endEditing
{
    [_textView resignFirstResponder];
    _textView.editable = false;
    _textView.selectable = false;
    
    if (self.finishedEditing != nil)
        self.finishedEditing(self);
}

#pragma mark -

- (void)textViewDidChange:(UITextView *)__unused textView
{
    [self sizeToFit];
    [_textView setNeedsDisplay];
}

#pragma mark -

- (void)setSwatch:(TGPaintSwatch *)swatch
{
    _swatch = swatch;
    [self updateColor];
}

- (void)setFont:(TGPhotoPaintFont *)font
{
    _font = font;
    _textView.font = [UIFont boldSystemFontOfSize:_baseFontSize];
    [self sizeToFit];
}

- (void)setStroke:(bool)stroke
{
    _stroke = stroke;
    if (stroke)
    {
        _textView.layer.shadowRadius = 0.0f;
        _textView.layer.shadowOpacity = 0.0f;
        _textView.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
        _textView.layer.shadowColor = [[UIColor clearColor] CGColor];
    }
    else
    {
        _textView.layer.shadowColor = [[UIColor blackColor] CGColor];
        _textView.layer.shadowOffset = CGSizeMake(0.0f, 4.0f);
        _textView.layer.shadowOpacity = 0.4f;
        _textView.layer.shadowRadius = 4.0f;
    }
    
    [self updateColor];
    [self setNeedsLayout];
}

- (void)updateColor
{
    if (_stroke)
    {
        _textView.textColor = [UIColor whiteColor];
        _textView.strokeColor = _swatch.color;
    }
    else
    {
        _textView.textColor = _swatch.color;
        _textView.strokeColor = nil;
    }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)__unused event
{
    CGFloat x = floor(_textView.font.pointSize / 2.2f);
    CGFloat y = floor(_textView.font.pointSize / 3.2f);
    if (self.selectionView != nil)
        return CGRectContainsPoint(CGRectInset(self.bounds, -(x + 10), -(y + 10)), point);
    else
        return [_textView pointInside:[_textView convertPoint:point fromView:self] withEvent:nil];
}

- (bool)precisePointInside:(CGPoint)point
{
    return [_textView pointInside:[_textView convertPoint:point fromView:self] withEvent:nil];
}

- (CGSize)sizeThatFits:(CGSize)__unused size
{
    CGSize result = [_textView sizeThatFits:CGSizeMake(_maxWidth, FLT_MAX)];
    result.width = MAX(224, ceil(result.width) + 20.0f);
    result.height = ceil(result.height) + 20.0f + _textView.font.pointSize * _font.sizeCorrection;
    return result;
}

- (void)sizeToFit
{
    CGPoint center = self.center;
    CGAffineTransform transform = self.transform;
    self.transform = CGAffineTransformIdentity;
    [super sizeToFit];
    self.center = center;
    self.transform = transform;
    
    if (self.entityChanged != nil)
        self.entityChanged(self);
}

- (CGRect)selectionBounds
{
    CGFloat x = floor(_textView.font.pointSize / 2.8f);
    CGFloat y = floor(_textView.font.pointSize / 4.0f);
    CGRect bounds = CGRectInset(self.bounds, -x, -y);
    CGSize size = CGSizeMake(bounds.size.width * self.scale, bounds.size.height * self.scale);
    return CGRectMake((self.bounds.size.width - size.width) / 2.0f, (self.bounds.size.height - size.height) / 2.0f, size.width, size.height);
}

- (TGPhotoPaintEntitySelectionView *)createSelectionView
{
    TGPhotoTextSelectionView *view = [[TGPhotoTextSelectionView alloc] init];
    view.entityView = self;
    return view;
}

- (void)layoutSubviews
{
    CGRect rect = self.bounds;
    CGFloat correction = _textView.font.pointSize * _font.sizeCorrection;
    rect.origin.y += correction;
    rect.size.height -= correction;
    rect = CGRectOffset(rect, 0.0f, 10.0f);
    
    _textView.frame = rect;
}

@end


@implementation TGPhotoTextSelectionView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        
        _leftHandle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, TGPhotoTextSelectionViewHandleSide, TGPhotoTextSelectionViewHandleSide)];
        [self addSubview:_leftHandle];
        
        _leftGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _leftGestureRecognizer.delegate = self;
        [_leftHandle addGestureRecognizer:_leftGestureRecognizer];
        
        _rightHandle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, TGPhotoTextSelectionViewHandleSide, TGPhotoTextSelectionViewHandleSide)];
        [self addSubview:_rightHandle];
        
        _rightGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _rightGestureRecognizer.delegate = self;
        [_rightHandle addGestureRecognizer:_rightGestureRecognizer];
    }
    return self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    bool (^isTracking)(UIGestureRecognizer *) = ^bool (UIGestureRecognizer *recognizer)
    {
        return (recognizer.state == UIGestureRecognizerStateBegan || recognizer.state == UIGestureRecognizerStateChanged);
    };
    
    if (self.entityView.shouldTouchEntity != nil && !self.entityView.shouldTouchEntity(self.entityView))
        return false;
    
    if (gestureRecognizer == _leftGestureRecognizer)
        return !isTracking(_rightGestureRecognizer);
    
    if (gestureRecognizer == _rightGestureRecognizer)
        return !isTracking(_leftGestureRecognizer);
    
    return true;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    if (view == self)
        return nil;
    
    return view;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)__unused event
{
    return CGRectContainsPoint(CGRectInset(self.bounds, -10.0f, -10.0f), point);
}

- (bool)isTracking
{
    bool (^isTracking)(UIGestureRecognizer *) = ^bool (UIGestureRecognizer *recognizer)
    {
        return (recognizer.state == UIGestureRecognizerStateBegan || recognizer.state == UIGestureRecognizerStateChanged);
    };
    
    return isTracking(_leftGestureRecognizer) || isTracking(_rightGestureRecognizer);
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    CGPoint parentLocation = [gestureRecognizer locationInView:self.superview];
    
    if (gestureRecognizer.state == UIGestureRecognizerStateChanged)
    {
        CGFloat deltaX = [gestureRecognizer translationInView:self].x;
        if (gestureRecognizer.view == _leftHandle)
            deltaX *= - 1;
        CGFloat scaleDelta = (self.bounds.size.width + deltaX * 2) / self.bounds.size.width;
        
        if (self.entityResized != nil)
            self.entityResized(scaleDelta);
        
        CGFloat angle = 0.0f;
        if (gestureRecognizer.view == _leftHandle)
            angle = atan2(self.center.y - parentLocation.y, self.center.x - parentLocation.x);
        if (gestureRecognizer.view == _rightHandle)
            angle = atan2(parentLocation.y - self.center.y, parentLocation.x - self.center.x);
        
        if (self.entityRotated != nil)
            self.entityRotated(angle);
        
        [gestureRecognizer setTranslation:CGPointZero inView:self];
    }
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGFloat space = 3.0f;
    CGFloat length = 3.0f;
    CGFloat thickness = 1;
    CGRect selectionBounds = CGRectInset(rect, 5.5f, 5.5f);
    
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetShadowWithColor(context, CGSizeZero, 2.5f, [UIColor colorWithWhite:0.0f alpha:0.3f].CGColor);
    
    CGPoint centerPoint = TGPaintCenterOfRect(rect);
    
    NSInteger xCount = (NSInteger)(floor(selectionBounds.size.width / (space + length)));
    CGFloat xGap = ceil(((selectionBounds.size.width - xCount * (space + length)) + space) / 2.0f);
    for (NSInteger i = 0; i < xCount; i++)
    {
        CGContextAddRect(context, CGRectMake(xGap + selectionBounds.origin.x + i * (length + space), selectionBounds.origin.y - thickness / 2.0f, length, thickness));
        
        CGContextAddRect(context, CGRectMake(xGap + selectionBounds.origin.x + i * (length + space), selectionBounds.origin.y + selectionBounds.size.height - thickness / 2.0f, length, thickness));
    }
    
    NSInteger yCount = (NSInteger)(floor(selectionBounds.size.height / (space + length)));
    CGFloat yGap = ceil(((selectionBounds.size.height - yCount * (space + length)) + space) / 2.0f);
    for (NSInteger i = 0; i < yCount; i++)
    {
        CGContextAddRect(context, CGRectMake(selectionBounds.origin.x - thickness / 2.0f, yGap + selectionBounds.origin.y + i * (length + space), thickness, length));
        
        CGContextAddRect(context, CGRectMake(selectionBounds.origin.x + selectionBounds.size.width - thickness / 2.0f, yGap + selectionBounds.origin.y + i * (length + space), thickness, length));
    }
    
    CGContextFillPath(context);
    
    CGContextSetFillColorWithColor(context, TGAccentColor().CGColor);
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, thickness);
    
    void (^drawEllipse)(CGPoint) = ^(CGPoint center)
    {
        CGContextSetShadowWithColor(context, CGSizeZero, 2.5f, [UIColor clearColor].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(center.x - 4.5f, center.y - 4.5f, 9.0f, 9.0f));
        CGContextStrokeEllipseInRect(context, CGRectMake(center.x - 4.5f, center.y - 4.5f, 9.0f, 9.0f));
    };
    
    drawEllipse(CGPointMake(5.5f, centerPoint.y));
    drawEllipse(CGPointMake(rect.size.width - 5.5f, centerPoint.y));
}

- (void)layoutSubviews
{
    _leftHandle.frame = CGRectMake(-9.5f, floor((self.bounds.size.height - _leftHandle.frame.size.height) / 2.0f), _leftHandle.frame.size.width, _leftHandle.frame.size.height);
    _rightHandle.frame = CGRectMake(self.bounds.size.width - _rightHandle.frame.size.width + 9.5f, floor((self.bounds.size.height - _rightHandle.frame.size.height) / 2.0f), _rightHandle.frame.size.width, _rightHandle.frame.size.height);
}

@end


@implementation TGPhotoTextView

- (instancetype)initWithFrame:(CGRect)frame
{
    NSTextStorage *textStorage = [[NSTextStorage alloc] init];
    TGPhotoTextLayoutManager *layoutManager = [[TGPhotoTextLayoutManager alloc] init];
    
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(0.0f, CGFLOAT_MAX)];
    container.widthTracksTextView = true;
    [layoutManager addTextContainer:container];
    [textStorage addLayoutManager:layoutManager];
    
    return [self initWithFrame:frame textContainer:container];;
}

- (CGRect)caretRectForPosition:(UITextPosition *)position
{
    CGRect rect = [super caretRectForPosition:position];
    rect.size.width = rect.size.height / 25.0f;
    return rect;
}

- (CGFloat)strokeWidth
{
    return ((TGPhotoTextLayoutManager *)self.layoutManager).strokeWidth;
}

- (void)setStrokeWidth:(CGFloat)strokeWidth
{
    [(TGPhotoTextLayoutManager *)self.layoutManager setStrokeWidth:strokeWidth];
    [self setNeedsDisplay];
}

- (UIColor *)strokeColor
{
    return ((TGPhotoTextLayoutManager *)self.layoutManager).strokeColor;
}

- (void)setStrokeColor:(UIColor *)strokeColor
{
    [(TGPhotoTextLayoutManager *)self.layoutManager setStrokeColor:strokeColor];
    [self setNeedsDisplay];
}

- (CGPoint)strokeOffset
{
    return ((TGPhotoTextLayoutManager *)self.layoutManager).strokeOffset;
}

- (void)setStrokeOffset:(CGPoint)strokeOffset
{
    [(TGPhotoTextLayoutManager *)self.layoutManager setStrokeOffset:strokeOffset];
    [self setNeedsDisplay];
}

@end


@implementation TGPhotoTextLayoutManager

- (void)showCGGlyphs:(const CGGlyph *)glyphs positions:(const CGPoint *)positions count:(NSUInteger)glyphCount font:(UIFont *)font matrix:(CGAffineTransform)textMatrix attributes:(NSDictionary<NSString *,id> *)attributes inContext:(CGContextRef)context
{
    if (self.strokeColor != nil)
    {
        CGContextSetStrokeColorWithColor(context, self.strokeColor.CGColor);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        
        CGFloat lineWidth = self.strokeWidth > FLT_EPSILON ? self.strokeWidth : floor(font.pointSize / 9.0f);
        CGContextSetLineWidth(context, lineWidth);
        CGContextSetTextDrawingMode(context, kCGTextStroke);
        
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, self.strokeOffset.x, self.strokeOffset.y);
        
        [super showCGGlyphs:glyphs positions:positions count:glyphCount font:font matrix:textMatrix attributes:attributes inContext:context];
        
        CGContextRestoreGState(context);
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextSetTextDrawingMode(context, kCGTextFill);
    }
    [super showCGGlyphs:glyphs positions:positions count:glyphCount font:font matrix:textMatrix attributes:attributes inContext:context];
}

@end
