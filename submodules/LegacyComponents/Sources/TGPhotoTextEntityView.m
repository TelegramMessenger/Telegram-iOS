#import "TGPhotoTextEntityView.h"

#import "TGPaintSwatch.h"
#import "TGPhotoPaintFont.h"

#import "TGColor.h"
#import "LegacyComponentsInternal.h"

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
@property (nonatomic, assign) UIColor *frameColor;
@property (nonatomic, assign) CGFloat frameWidthInset;
@property (nonatomic, assign) CGFloat frameCornerRadius;

@end


@interface TGPhotoTextStorage : NSTextStorage

@end


@interface TGPhotoTextEntityView () <UITextViewDelegate>
{
    TGPaintSwatch *_swatch;
    TGPhotoPaintFont *_font;
    CGFloat _baseFontSize;
    CGFloat _maxWidth;
    TGPhotoPaintTextEntityStyle _style;
    
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
        _textView.showsVerticalScrollIndicator = false;;
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
        _textView.typingAttributes = @{NSFontAttributeName: _textView.font};
//        _textView.frameWidthInset = floor(_baseFontSize * 0.03);
        
        [self setSwatch:entity.swatch];
        [self setStyle:entity.style];
    
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
    TGPhotoPaintTextEntity *entity = [[TGPhotoPaintTextEntity alloc] initWithText:_textView.text font:_font swatch:_swatch baseFontSize:_baseFontSize maxWidth:_maxWidth style:_style];
    entity.uuid = _entityUUID;
    entity.angle = self.angle;
    entity.scale = self.scale;
    entity.position = self.center;
    
    return entity;
}

- (UIImage *)image {
    CGRect rect = self.bounds;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(rect.size.width, rect.size.height), false, 1.0f);
    
    [self drawViewHierarchyInRect:rect afterScreenUpdates:false];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
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
    
    _textView.text = [_textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
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
    _textView.typingAttributes = @{NSFontAttributeName: _textView.font};
//    _textView.frameWidthInset = floor(_baseFontSize * 0.03);
    
    [self sizeToFit];
}

- (void)setStyle:(TGPhotoPaintTextEntityStyle)style
{
    _style = style;
    switch (_style) {
        case TGPhotoPaintTextEntityStyleRegular:
            _textView.layer.shadowColor = [UIColorRGB(0x000000) CGColor];
            _textView.layer.shadowOffset = CGSizeMake(0.0f, 4.0f);
            _textView.layer.shadowOpacity = 0.4f;
            _textView.layer.shadowRadius = 4.0f;
            break;
            
        default:
            _textView.layer.shadowRadius = 0.0f;
            _textView.layer.shadowOpacity = 0.0f;
            _textView.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
            _textView.layer.shadowColor = [[UIColor clearColor] CGColor];
            break;
    }
    
    [self updateColor];
    [self setNeedsLayout];
}

- (void)updateColor
{
    switch (_style) {
        case TGPhotoPaintTextEntityStyleRegular:
        {
            _textView.textColor = _swatch.color;
            _textView.strokeColor = nil;
            _textView.frameColor = nil;
        }
            break;
            
        case TGPhotoPaintTextEntityStyleOutlined:
        {
            _textView.textColor = UIColorRGB(0xffffff);
            _textView.strokeColor = _swatch.color;
            _textView.frameColor = nil;
        }
            break;
            
        case TGPhotoPaintTextEntityStyleFramed:
        {
            CGFloat lightness = 0.0f;
            CGFloat r = 0.0f;
            CGFloat g = 0.0f;
            CGFloat b = 0.0f;
            
            if ([_swatch.color getRed:&r green:&g blue:&b alpha:NULL]) {
                lightness = 0.2126f * r + 0.7152f * g + 0.0722f * b;
            } else if ([_swatch.color getWhite:&r alpha:NULL]) {
                lightness = r;
            }
            
            if (lightness > 0.87) {
                _textView.textColor = UIColorRGB(0x000000);
            } else {
                _textView.textColor = UIColorRGB(0xffffff);
            }
            _textView.strokeColor = nil;
            _textView.frameColor = _swatch.color;
        }
            break;
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
    
    CGFloat space = 4.0f;
    CGFloat length = 4.5f;
    CGFloat thickness = 1.5f;
    CGRect selectionBounds = CGRectInset(rect, 5.5f, 5.5f);
    
    UIColor *color = UIColorRGBA(0xeaeaea, 0.8);
    
    CGContextSetFillColorWithColor(context, color.CGColor);
    
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
    
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, thickness);
    
    void (^drawEllipse)(CGPoint, bool) = ^(CGPoint center, bool clear)
    {
        CGRect rect = CGRectMake(center.x - 4.5f, center.y - 4.5f, 9.0f, 9.0f);
        if (clear) {
            rect = CGRectInset(rect, -thickness, -thickness);
            CGContextFillEllipseInRect(context, rect);
        } else {
            CGContextStrokeEllipseInRect(context, rect);
        }
    };
    
    CGContextSetBlendMode(context, kCGBlendModeClear);
    
    drawEllipse(CGPointMake(5.5f, centerPoint.y), true);
    drawEllipse(CGPointMake(rect.size.width - 5.5f, centerPoint.y), true);
    
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    
    drawEllipse(CGPointMake(5.5f, centerPoint.y), false);
    drawEllipse(CGPointMake(rect.size.width - 5.5f, centerPoint.y), false);
}

- (void)layoutSubviews
{
    _leftHandle.frame = CGRectMake(-9.5f, floor((self.bounds.size.height - _leftHandle.frame.size.height) / 2.0f), _leftHandle.frame.size.width, _leftHandle.frame.size.height);
    _rightHandle.frame = CGRectMake(self.bounds.size.width - _rightHandle.frame.size.width + 9.5f, floor((self.bounds.size.height - _rightHandle.frame.size.height) / 2.0f), _rightHandle.frame.size.width, _rightHandle.frame.size.height);
}

@end


@implementation TGPhotoTextView
{
    UIFont *_font;
    UIColor *_forcedTextColor;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    TGPhotoTextStorage *textStorage = [[TGPhotoTextStorage alloc] init];
    TGPhotoTextLayoutManager *layoutManager = [[TGPhotoTextLayoutManager alloc] init];
    
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(0.0f, CGFLOAT_MAX)];
    container.widthTracksTextView = true;
    [layoutManager addTextContainer:container];
    [textStorage addLayoutManager:layoutManager];
    
    return [self initWithFrame:frame textContainer:container];
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

- (UIColor *)frameColor {
    return ((TGPhotoTextLayoutManager *)self.layoutManager).frameColor;
}

- (void)setFrameColor:(UIColor *)frameColor {
    [(TGPhotoTextLayoutManager *)self.layoutManager setFrameColor:frameColor];
    [self setNeedsDisplay];
}

- (CGFloat)frameWidthInset {
    return ((TGPhotoTextLayoutManager *)self.layoutManager).frameWidthInset;
}

- (void)setFrameWidthInset:(CGFloat)frameWidthInset {
    [(TGPhotoTextLayoutManager *)self.layoutManager setFrameWidthInset:frameWidthInset];
    [self setNeedsDisplay];
}

- (void)setFont:(UIFont *)font {
    [super setFont:font];
    _font = font;
    
    self.layoutManager.textContainers.firstObject.lineFragmentPadding = floor(font.pointSize * 0.3);
}

- (void)setTextColor:(UIColor *)textColor {
    _forcedTextColor = textColor;
    [super setTextColor:textColor];
}

- (void)insertText:(NSString *)text {
    [self fixTypingAttributes];
    [super insertText:text];
    [self fixTypingAttributes];
}

- (void)paste:(id)sender {
    [self fixTypingAttributes];
    [super paste:sender];
    [self fixTypingAttributes];
}

- (void)fixTypingAttributes {
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    if (_font != nil) {
        attributes[NSFontAttributeName] = _font;
    }
    if (_forcedTextColor != nil) {
        attributes[NSForegroundColorAttributeName] = _forcedTextColor;
    }
    self.typingAttributes = attributes;
}

@end


@implementation TGPhotoTextLayoutManager
{
    CGFloat _radius;
    NSInteger _maxIndex;
    NSArray *_pointArray;
    UIBezierPath *_path;
    NSMutableArray *_rectArray;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _radius = 8.0f;
    }
    return self;
}

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

- (void)prepare {
    _path = nil;
    [self.rectArray removeAllObjects];
    
    [self enumerateLineFragmentsForGlyphRange:NSMakeRange(0, self.textStorage.string.length) usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
        bool ignoreRange = false;
        NSRange characterRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:nil];
        NSString *substring = [[self.textStorage string] substringWithRange:characterRange];
        if ([substring stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]].length == 0) {
            ignoreRange = true;
        }
         
         if (!ignoreRange) {
             CGRect newRect = CGRectMake(usedRect.origin.x - self.frameWidthInset, usedRect.origin.y, usedRect.size.width + self.frameWidthInset * 2, usedRect.size.height);
             NSValue *value = [NSValue valueWithCGRect:newRect];
             [self.rectArray addObject:value];
         }
     }];
    
     [self preProccess];
}

- (void)drawBackgroundForGlyphRange:(NSRange)glyphsToShow atPoint:(CGPoint)origin {
//    [super drawBackgroundForGlyphRange:glyphsToShow atPoint:origin];
    
    if (self.frameColor != nil) {
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, origin.x, origin.y);
        
        CGContextSetBlendMode(context, kCGBlendModeNormal);
        CGContextSetFillColorWithColor(context, self.frameColor.CGColor);
        CGContextSetStrokeColorWithColor(context, self.frameColor.CGColor);
        
        [self prepare];
//        _path = nil;
//        [self.rectArray removeAllObjects];
//
//        [self enumerateLineFragmentsForGlyphRange:glyphRange usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
//            bool ignoreRange = false;
//            NSString *substring = [[self.textStorage string] substringWithRange:glyphRange];
//            if ([substring stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]].length == 0) {
//                ignoreRange = true;
//            }
//
//            if (!ignoreRange) {
//                CGRect newRect = CGRectMake(usedRect.origin.x - self.frameWidthInset, usedRect.origin.y, usedRect.size.width + self.frameWidthInset * 2, usedRect.size.height);
//                NSValue *value = [NSValue valueWithCGRect:newRect];
//                [self.rectArray addObject:value];
//            }
//        }];
       
        [self preProccess];
       
        CGRect last = CGRectNull;
        for (int i = 0; i < self.rectArray.count; i ++) {
            NSValue *curValue = [self.rectArray objectAtIndex:i];
            CGRect cur = curValue.CGRectValue;
            _radius = cur.size.height * 0.18;
            [self.path appendPath:[UIBezierPath bezierPathWithRoundedRect:cur cornerRadius:_radius]];
            if (i == 0) {
                last = cur;
            } else if (i > 0 && fabs(CGRectGetMaxY(last) - CGRectGetMinY(cur)) < 10.0) {
                CGPoint a = cur.origin;
                CGPoint b = CGPointMake(CGRectGetMaxX(cur), cur.origin.y);
                CGPoint c = CGPointMake(last.origin.x, CGRectGetMaxY(last));
                CGPoint d = CGPointMake(CGRectGetMaxX(last), CGRectGetMaxY(last));
                
                if (a.x - c.x >= 2 * _radius) {
                    UIBezierPath *addPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(a.x - _radius, a.y + _radius) radius:_radius startAngle:M_PI_2 * 3 endAngle:0 clockwise:YES];
                    
                    [addPath appendPath:[UIBezierPath bezierPathWithArcCenter:CGPointMake(a.x + _radius, a.y + _radius) radius:_radius startAngle:M_PI endAngle:3 * M_PI_2 clockwise:YES]];
                    [addPath addLineToPoint:CGPointMake(a.x - _radius, a.y)];
                    [self.path appendPath:addPath];
                }
                if (a.x == c.x) {
                    [self.path moveToPoint:CGPointMake(a.x, a.y - _radius)];
                    [self.path addLineToPoint:CGPointMake(a.x, a.y + _radius)];
                    [self.path addArcWithCenter:CGPointMake(a.x + _radius, a.y + _radius) radius:_radius startAngle:M_PI endAngle:M_PI_2 * 3 clockwise:YES];
                    [self.path addArcWithCenter:CGPointMake(a.x + _radius, a.y - _radius) radius:_radius startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
                }
                if (d.x - b.x >= 2 * _radius) {
                    UIBezierPath *addPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(b.x + _radius, b.y + _radius) radius:_radius startAngle:M_PI_2 * 3 endAngle:M_PI clockwise:NO];
                    [addPath appendPath:[UIBezierPath bezierPathWithArcCenter:CGPointMake(b.x - _radius, b.y + _radius) radius:_radius startAngle:0 endAngle:3 * M_PI_2 clockwise:NO]];
                    [addPath addLineToPoint:CGPointMake(b.x + _radius, b.y)];
                    [self.path appendPath:addPath];
                }
                if (d.x == b.x) {
                    [self.path moveToPoint:CGPointMake(b.x, b.y - _radius)];
                    [self.path addLineToPoint:CGPointMake(b.x, b.y + _radius)];
                    [self.path addArcWithCenter:CGPointMake(b.x - _radius, b.y + _radius) radius:_radius startAngle:0 endAngle:M_PI_2 * 3 clockwise:NO];
                    [self.path addArcWithCenter:CGPointMake(b.x - _radius, b.y - _radius) radius:_radius startAngle:M_PI_2 endAngle:0 clockwise:NO];
                }
                if (c.x - a.x >= 2 * _radius) {
                    UIBezierPath *addPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(c.x - _radius, c.y - _radius) radius:_radius startAngle:M_PI_2 endAngle:0 clockwise:NO];
                    [addPath appendPath:[UIBezierPath bezierPathWithArcCenter:CGPointMake(c.x + _radius, c.y - _radius) radius:_radius startAngle:M_PI endAngle:M_PI_2 clockwise:NO]];
                    [addPath addLineToPoint:CGPointMake(c.x - _radius, c.y)];
                    [self.path appendPath:addPath];
                }
                if (b.x - d.x >= 2 * _radius) {
                    UIBezierPath *addPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(d.x + _radius, d.y - _radius) radius:_radius startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
                    [addPath appendPath:[UIBezierPath bezierPathWithArcCenter:CGPointMake(d.x - _radius, d.y - _radius) radius:_radius startAngle:0 endAngle:M_PI_2 clockwise:YES]];
                    [addPath addLineToPoint:CGPointMake(d.x + _radius, d.y)];
                    [self.path appendPath:addPath];
                }
                
                last = cur;
            }
        }
        [self.path fill];
        [self.path stroke];
        
        CGContextRestoreGState(context);
    }
}

- (UIBezierPath *)path {
    if (!_path) {
        _path = [UIBezierPath bezierPath];
    }
    return _path;
}

- (NSMutableArray *)rectArray {
    if (!_rectArray) {
        _rectArray = [[NSMutableArray alloc] init];
    }
    return _rectArray;
}

- (void)preProccess {
    _maxIndex = 0;
    if (self.rectArray.count < 2) {
        return;
    }
    for (int i = 1; i < self.rectArray.count; i++) {
        _maxIndex = i;
        [self processRectIndex:i];
    }
}

- (void)processRectIndex:(int) index {
    if (self.rectArray.count < 2 || index < 1 || index > _maxIndex) {
        return;
    }
    NSValue *value1 = [self.rectArray objectAtIndex:index - 1];
    NSValue *value2 = [self.rectArray objectAtIndex:index];
    CGRect last = value1.CGRectValue;
    CGRect cur = value2.CGRectValue;
    _radius = cur.size.height * 0.18;
    
    BOOL t1 = ((cur.origin.x - last.origin.x < 2 * _radius) && (cur.origin.x > last.origin.x)) || ((CGRectGetMaxX(cur) - CGRectGetMaxX(last) > -2 * _radius) && (CGRectGetMaxX(cur) < CGRectGetMaxX(last)));
    BOOL t2 = ((last.origin.x - cur.origin.x < 2 * _radius) && (last.origin.x > cur.origin.x)) || ((CGRectGetMaxX(last) - CGRectGetMaxX(cur) > -2 * _radius) && (CGRectGetMaxX(last) < CGRectGetMaxX(cur)));
    
    if (t2) {
        CGRect newRect = CGRectMake(cur.origin.x, last.origin.y, cur.size.width, last.size.height);
        NSValue *newValue = [NSValue valueWithCGRect:newRect];
        [self.rectArray replaceObjectAtIndex:index - 1 withObject:newValue];
        [self processRectIndex:index - 1];
    }
    if (t1) {
        CGRect newRect = CGRectMake(last.origin.x, cur.origin.y, last.size.width, cur.size.height);
        NSValue *newValue = [NSValue valueWithCGRect:newRect];
        [self.rectArray replaceObjectAtIndex:index withObject:newValue];
        [self processRectIndex:index + 1];
    }
    return;
}

@end


@implementation TGPhotoTextStorage
{
    NSTextStorage *_impl;
}

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        _impl = [NSTextStorage new];
    }
    
    return self;
}

- (NSString *)string
{
    return _impl.string;
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
    return [_impl attributesAtIndex:location effectiveRange:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
    [self beginEditing];
    [_impl replaceCharactersInRange:range withString:str];
    [self edited:NSTextStorageEditedCharacters range:range changeInLength:(NSInteger)str.length - (NSInteger)range.length];
    [self endEditing];
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey,id> *)attrs range:(NSRange)range {
    [self beginEditing];
    [_impl setAttributes:attrs range:range];
    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
    [self endEditing];
}

@end
