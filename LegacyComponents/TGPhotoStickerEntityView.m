#import "TGPhotoStickerEntityView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGPaintUtils.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>

#import "TGDocumentMediaAttachment.h"
#import "TGStringUtils.h"
#import "TGImageUtils.h"
#import "TGColor.h"

#import "TGImageView.h"

const CGFloat TGPhotoStickerSelectionViewHandleSide = 30.0f;

@interface UIView (OpaquePixel)

- (bool)isOpaqueAtPoint:(CGPoint)pixelPoint;

@end

@interface TGPhotoStickerSelectionView () <UIGestureRecognizerDelegate>
{
    UIView *_leftHandle;
    UIView *_rightHandle;
    
    UIPanGestureRecognizer *_leftGestureRecognizer;
    UIPanGestureRecognizer *_rightGestureRecognizer;
}
@end


@interface TGPhotoStickerEntityView ()
{
    TGImageView *_imageView;
    
    TGDocumentMediaAttachment *_document;
    bool _mirrored;
    
    CGSize _baseSize;
    CATransform3D _defaultTransform;
}
@end

@implementation TGPhotoStickerEntityView

- (instancetype)initWithEntity:(TGPhotoPaintStickerEntity *)entity
{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, entity.baseSize.width, entity.baseSize.height)];
    if (self != nil)
    {
        _entityUUID = entity.uuid;
        _baseSize = entity.baseSize;
        _mirrored = entity.isMirrored;
        
        _imageView = [[TGImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.expectExtendedEdges = true;
        [self addSubview:_imageView];
        
        TGDocumentMediaAttachment *sticker = entity.document;
        _document = sticker;
        
        CGSize imageSize = CGSizeZero;
        bool isSticker = false;
        for (id attribute in sticker.attributes)
        {
            if ([attribute isKindOfClass:[TGDocumentAttributeImageSize class]])
                imageSize = ((TGDocumentAttributeImageSize *)attribute).size;
            else if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]])
                isSticker = true;
        }
        
        CGSize displaySize = [self fittedSizeForSize:imageSize maxSize:CGSizeMake(512.0f, 512.0f)];
        
        NSMutableString *imageUri = [[NSMutableString alloc] init];
        [imageUri appendString:@"sticker://?"];
        if (sticker.documentId != 0)
        {
            [imageUri appendFormat:@"&documentId=%" PRId64, sticker.documentId];
            
            TGMediaOriginInfo *originInfo = sticker.originInfo ?: [TGMediaOriginInfo mediaOriginInfoForDocumentAttachment:sticker];
            if (originInfo != nil)
                [imageUri appendFormat:@"&origin_info=%@", [originInfo stringRepresentation]];
        }
        else
        {
            [imageUri appendFormat:@"&localDocumentId=%" PRId64, sticker.localDocumentId];
        }
        [imageUri appendFormat:@"&accessHash=%" PRId64, sticker.accessHash];
        [imageUri appendFormat:@"&datacenterId=%d", (int)sticker.datacenterId];
        [imageUri appendFormat:@"&fileName=%@", [TGStringUtils stringByEscapingForURL:sticker.fileName]];
        [imageUri appendFormat:@"&size=%d", (int)sticker.size];
        [imageUri appendFormat:@"&width=%d&height=%d", (int)displaySize.width, (int)displaySize.height];
        [imageUri appendFormat:@"&mime-type=%@", [TGStringUtils stringByEscapingForURL:sticker.mimeType]];
        [imageUri appendString:@"&inhibitBlur=1"];
        
        _imageView.frame = CGRectMake(CGFloor((self.frame.size.width - displaySize.width) / 2.0f), CGFloor((self.frame.size.height - displaySize.height) / 2.0f), displaySize.width, displaySize.height);
        
        CGFloat scale = displaySize.width > displaySize.height ? self.frame.size.width / displaySize.width : self.frame.size.height / displaySize.height;
        _defaultTransform = CATransform3DMakeScale(scale, scale, 1.0f);
        _imageView.layer.transform = _defaultTransform;
        
        if (_mirrored)
            _imageView.layer.transform = CATransform3DRotate(_defaultTransform, M_PI, 0, 1, 0);
        
        [_imageView loadUri:imageUri withOptions:@{}];
    }
    return self;
}


- (TGPhotoPaintStickerEntity *)entity
{
    TGPhotoPaintStickerEntity *entity = [[TGPhotoPaintStickerEntity alloc] initWithDocument:_document baseSize:_baseSize];
    entity.uuid = _entityUUID;
    entity.position = self.center;
    entity.scale = self.scale;
    entity.angle = self.angle;
    entity.mirrored = _mirrored;
    return entity;
}

- (CGRect)realBounds
{
    CGSize size = CGSizeMake(_baseSize.width * self.scale, _baseSize.height * self.scale);
    return CGRectMake(self.center.x - size.width / 2.0f, self.center.y - size.height / 2.0f, size.width, size.height);
}

- (bool)isMirrored
{
    return _mirrored;
}

- (CGSize)fittedSizeForSize:(CGSize)size maxSize:(CGSize)maxSize
{
    return TGFitSize(CGSizeMake(size.width, size.height), maxSize);
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)__unused event
{
    CGPoint center = CGPointMake(self.bounds.size.width / 2.0f, self.bounds.size.height / 2.0f);
    if (self.selectionView != nil)
    {
        CGFloat selectionRadius = self.bounds.size.width / sin(M_PI_4);
        return pow(point.x - center.x, 2) + pow(point.y - center.y, 2) < pow(selectionRadius / 2.0f, 2);
    }
    else
    {
        return [super pointInside:point withEvent:event];
    }
}

- (bool)precisePointInside:(CGPoint)point
{
    CGPoint imagePoint = [_imageView convertPoint:point fromView:self];
    if (![_imageView pointInside:[_imageView convertPoint:point fromView:self] withEvent:nil])
        return false;
    
    return [_imageView isOpaqueAtPoint:imagePoint];
}

- (void)mirror
{
    _mirrored = !_mirrored;
    
    if (iosMajorVersion() >= 7)
    {
        CATransform3D startTransform = _defaultTransform;
        if (!_mirrored)
        {
            startTransform = _imageView.layer.transform;
        }
        CATransform3D targetTransform = CATransform3DRotate(_defaultTransform, 0, 0, 1, 0);
        if (_mirrored)
        {
            targetTransform = CATransform3DRotate(_defaultTransform, M_PI, 0, 1, 0);
            targetTransform.m34 = -1.0f / _imageView.frame.size.width;
        }
        
        [UIView animateWithDuration:0.25 animations:^
        {
            _imageView.layer.transform = targetTransform;
        }];
    }
    else
    {
        _imageView.layer.transform = CATransform3DRotate(_defaultTransform, _mirrored ? M_PI : 0, 0, 1, 0);
    }
}

- (UIImage *)image
{
    return _imageView.currentImage;
}

- (TGPhotoPaintEntitySelectionView *)createSelectionView
{
    TGPhotoStickerSelectionView *view = [[TGPhotoStickerSelectionView alloc] init];
    view.entityView = self;
    return view;
}

- (CGRect)selectionBounds
{
    CGFloat side = self.bounds.size.width / sin(M_PI_4) * self.scale;
    return CGRectMake((self.bounds.size.width - side) / 2.0f, (self.bounds.size.height - side) / 2.0f, side, side);
}

@end


@implementation TGPhotoStickerSelectionView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        
        _leftHandle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, TGPhotoStickerSelectionViewHandleSide, TGPhotoStickerSelectionViewHandleSide)];
        [self addSubview:_leftHandle];
        
        _leftGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _leftGestureRecognizer.delegate = self;
        [_leftHandle addGestureRecognizer:_leftGestureRecognizer];
        
        _rightHandle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, TGPhotoStickerSelectionViewHandleSide, TGPhotoStickerSelectionViewHandleSide)];
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
    
    CGFloat thickness = 1;
    CGFloat radius = rect.size.width / 2.0f - 5.5f;
    
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetShadowWithColor(context, CGSizeZero, 2.5f, [UIColor colorWithWhite:0.0f alpha:0.3f].CGColor);
    
    CGFloat radSpace = TGDegreesToRadians(4.0f);
    CGFloat radLen = TGDegreesToRadians(4.0f);
    
    CGPoint centerPoint = TGPaintCenterOfRect(rect);
    
    for (NSInteger i = 0; i < 48; i++)
    {
        CGMutablePathRef path = CGPathCreateMutable();
        
        CGPathAddArc(path, NULL, centerPoint.x, centerPoint.y, radius, i * (radSpace + radLen), i * (radSpace + radLen) + radLen, false);
        
        CGPathRef strokedArc = CGPathCreateCopyByStrokingPath(path, NULL, thickness, kCGLineCapButt, kCGLineJoinMiter, 10);
        
        CGContextAddPath(context, strokedArc);
        
        CGPathRelease(strokedArc);
        CGPathRelease(path);
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

@implementation UIView (OpaquePixel)

- (bool)isOpaqueAtPoint:(CGPoint)point
{
    if (point.x > self.bounds.size.width || point.y > self.bounds.size.height)
        return false;
    
    unsigned char pixel[4] = {0};
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, colorSpace, kCGBitmapAlphaInfoMask & kCGImageAlphaPremultipliedLast);
    
    CGContextTranslateCTM(context, -point.x, -point.y);
    
    [self.layer renderInContext:context];
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    return pixel[3] > 16;
}

@end
