#import "TGPhotoEntitiesContainerView.h"
#import "TGPhotoPaintEntityView.h"
#import "TGPhotoStickerEntityView.h"
#import "TGPhotoTextEntityView.h"
#import "TGPaintingData.h"

#import <LegacyComponents/TGPhotoEditorUtils.h>

@interface TGPhotoEntitiesContainerView () <UIGestureRecognizerDelegate>
{
    TGPhotoPaintEntityView *_currentView;
    UITapGestureRecognizer *_tapGestureRecognizer;
}
@end

@implementation TGPhotoEntitiesContainerView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        _tapGestureRecognizer.delegate = self;
        [self addGestureRecognizer:_tapGestureRecognizer];
    }
    return self;
}

- (void)updateVisibility:(bool)visible
{
    for (TGPhotoPaintEntityView *view in self.subviews)
    {
        if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
            continue;
        
        if ([view isKindOfClass:[TGPhotoStickerEntityView class]]) {
            [(TGPhotoStickerEntityView *)view updateVisibility:visible];
        }
    }
}

- (void)seekTo:(double)timestamp {
    for (TGPhotoPaintEntityView *view in self.subviews)
    {
        if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
            continue;
           
        if ([view isKindOfClass:[TGPhotoStickerEntityView class]]) {
            [(TGPhotoStickerEntityView *)view seekTo:timestamp];
        }
    }
}

- (void)play {
    for (TGPhotoPaintEntityView *view in self.subviews)
    {
        if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
            continue;
        
        if ([view isKindOfClass:[TGPhotoStickerEntityView class]]) {
            [(TGPhotoStickerEntityView *)view play];
        }
    }
}

- (void)pause {
    for (TGPhotoPaintEntityView *view in self.subviews)
    {
        if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
            continue;
        
        if ([view isKindOfClass:[TGPhotoStickerEntityView class]]) {
            [(TGPhotoStickerEntityView *)view pause];
        }
    }
}


- (void)resetToStart {
    for (TGPhotoPaintEntityView *view in self.subviews)
    {
        if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
            continue;
        
        if ([view isKindOfClass:[TGPhotoStickerEntityView class]]) {
            [(TGPhotoStickerEntityView *)view resetToStart];
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)__unused gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)__unused otherGestureRecognizer
{
    return false;
}

- (void)handleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    CGPoint point = [gestureRecognizer locationInView:self];
    
    NSMutableArray *intersectedViews = [[NSMutableArray alloc] init];
    for (TGPhotoPaintEntityView *view in self.subviews)
    {
        if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
            continue;
        
        if ([view pointInside:[view convertPoint:point fromView:self] withEvent:nil])
            [intersectedViews addObject:view];
    }
    
    TGPhotoPaintEntityView *result = nil;
    if (intersectedViews.count > 1)
    {
        __block TGPhotoPaintEntityView *subresult = nil;
        [intersectedViews enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(TGPhotoPaintEntityView *view, __unused NSUInteger index, BOOL *stop)
        {
            if ([view precisePointInside:[view convertPoint:point fromView:self]])
            {
                subresult = view;
                *stop = true;
            }
        }];
        
        result = subresult ?: intersectedViews.lastObject;
    }
    else if (intersectedViews.count == 1)
    {
        result = intersectedViews.firstObject;
    }
    
    if (self.entitySelected != nil)
        self.entitySelected(result);
}

- (UIColor *)colorAtPoint:(CGPoint)point {
    NSMutableArray *intersectedViews = [[NSMutableArray alloc] init];
    for (TGPhotoPaintEntityView *view in self.subviews)
    {
        if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
            continue;
        
        if ([view pointInside:[view convertPoint:point fromView:self] withEvent:nil])
            [intersectedViews addObject:view];
    }
    
    TGPhotoPaintEntityView *result = nil;
    if (intersectedViews.count > 1)
    {
        __block TGPhotoPaintEntityView *subresult = nil;
        [intersectedViews enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(TGPhotoPaintEntityView *view, __unused NSUInteger index, BOOL *stop)
         {
            if ([view precisePointInside:[view convertPoint:point fromView:self]])
            {
                subresult = view;
                *stop = true;
            }
        }];
        
        result = subresult ?: intersectedViews.lastObject;
    }
    else if (intersectedViews.count == 1)
    {
        result = intersectedViews.firstObject;
    }
    
    return [result colorAtPoint:[result convertPoint:point fromView:self]];
}

- (NSUInteger)entitiesCount
{
    return MAX(0, (NSInteger)self.subviews.count - 1);
}

- (void)setupWithPaintingData:(TGPaintingData *)paintingData {
    [self removeAll];
    for (TGPhotoPaintEntity *entity in paintingData.entities) {
        [self createEntityViewWithEntity:entity];
    }
}

- (TGPhotoPaintEntityView *)createEntityViewWithEntity:(TGPhotoPaintEntity *)entity {
    if ([entity isKindOfClass:[TGPhotoPaintStickerEntity class]])
        return [self _createStickerViewWithEntity:(TGPhotoPaintStickerEntity *)entity];
    else if ([entity isKindOfClass:[TGPhotoPaintTextEntity class]])
        return [self _createTextViewWithEntity:(TGPhotoPaintTextEntity *)entity];
    
    return nil;
}

- (TGPhotoStickerEntityView *)_createStickerViewWithEntity:(TGPhotoPaintStickerEntity *)entity
{
    TGPhotoStickerEntityView *stickerView = [[TGPhotoStickerEntityView alloc] initWithEntity:entity context:self.stickersContext];
    [self _commonEntityViewSetup:stickerView entity:entity];
    [self addSubview:stickerView];

    return stickerView;
}

- (TGPhotoTextEntityView *)_createTextViewWithEntity:(TGPhotoPaintTextEntity *)entity
{
    TGPhotoTextEntityView *textView = [[TGPhotoTextEntityView alloc] initWithEntity:entity];
    [textView sizeToFit];
    
    [self _commonEntityViewSetup:textView entity:entity];
    [self addSubview:textView];
    
    return textView;
}

- (void)_commonEntityViewSetup:(TGPhotoPaintEntityView *)entityView entity:(TGPhotoPaintEntity *)entity
{
    entityView.transform = CGAffineTransformRotate(CGAffineTransformMakeScale(entity.scale, entity.scale), entity.angle);
    entityView.center = entity.position;
}

- (TGPhotoPaintEntityView *)viewForUUID:(NSInteger)uuid
{
    for (TGPhotoPaintEntityView *view in self.subviews)
    {
        if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
            continue;
        
        if (view.entityUUID == uuid)
            return view;
    }
    
    return nil;
}

- (void)removeViewWithUUID:(NSInteger)uuid
{
    for (TGPhotoPaintEntityView *view in self.subviews)
    {
        if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
            continue;
        
        if (view.entityUUID == uuid)
        {
            [view removeFromSuperview];
            
            if (self.entityRemoved != nil)
                self.entityRemoved(view);
            break;
        }
    }
}

- (void)removeAll
{
    for (TGPhotoPaintEntityView *view in self.subviews)
    {
        if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
            continue;
        
        [view removeFromSuperview];
    }
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer
{
    CGPoint location = [gestureRecognizer locationInView:self];
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (_currentView != nil)
                return;
            
            _currentView = [self viewForLocation:location];
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            if (_currentView == nil)
                return;
            
            CGFloat scale = gestureRecognizer.scale;
            [_currentView scale:scale absolute:false];
            
            [gestureRecognizer setScale:1.0f];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        {
            _currentView = nil;
        }
            break;
            
        case UIGestureRecognizerStateCancelled:
        {
            _currentView = nil;
        }
            break;
            
        default:
            break;
    }
}

- (void)handleRotate:(UIRotationGestureRecognizer *)gestureRecognizer
{
    CGPoint location = [gestureRecognizer locationInView:self];
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (_currentView != nil)
                return;
            
            _currentView = [self viewForLocation:location];
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            if (_currentView == nil)
                return;
            
            CGFloat rotation = gestureRecognizer.rotation;
            [_currentView rotate:rotation absolute:false];
            
            [gestureRecognizer setRotation:0.0f];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        {
            
        }
            break;
            
        case UIGestureRecognizerStateCancelled:
        {
            
        }
            break;
            
        default:
            break;
    }
}

- (TGPhotoPaintEntityView *)viewForLocation:(CGPoint)__unused location
{
    for (TGPhotoPaintEntityView *view in self.subviews)
    {
        if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
            continue;
        
        if (view.selectionView != nil)
            return view;
    }
    
    return nil;
}

- (UIImage *)imageInRect:(CGRect)rect background:(UIImage *)background still:(bool)still
{
    if (self.subviews.count < 2)
        return nil;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(rect.size.width, rect.size.height), false, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect bounds = CGRectMake(0, 0, rect.size.width, rect.size.height);
    [background drawInRect:bounds];
    
    for (TGPhotoPaintEntityView *view in self.subviews)
    {
        if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
            continue;
        
        if ([view isKindOfClass:[TGPhotoStickerEntityView class]])
        {
            [self drawView:view inContext:context withBlock:^
            {
                TGPhotoStickerEntityView *stickerView = (TGPhotoStickerEntityView *)view;
                UIImage *image = stickerView.image;
                if (image != nil) {
                    CGSize fittedSize = TGScaleToSize(image.size, view.bounds.size);
                    
                    CGContextTranslateCTM(context, view.bounds.size.width / 2.0f, view.bounds.size.height / 2.0f);
                    if (stickerView.isMirrored)
                        CGContextScaleCTM(context, -1, 1);
                    
                    [image drawInRect:CGRectMake(-fittedSize.width / 2.0f, -fittedSize.height / 2.0f, fittedSize.width, fittedSize.height)];
                }
            }];
        }
        else if ([view isKindOfClass:[TGPhotoTextEntityView class]])
        {
            [self drawView:view inContext:context withBlock:^
            {
                [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:false];
            }];
        }
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)drawView:(UIView *)view inContext:(CGContextRef)context withBlock:(void (^)(void))block
{
    CGContextSaveGState(context);
    
    CGContextTranslateCTM(context, view.center.x, view.center.y);
    CGContextConcatCTM(context, view.transform);
    CGContextTranslateCTM(context, -view.bounds.size.width / 2.0f, -view.bounds.size.height / 2.0f);
    
    block();
    
    CGContextRestoreGState(context);
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    bool pointInside = [super pointInside:point withEvent:event];
    if (!pointInside)
    {
        for (UIView *subview in self.subviews)
        {
            CGPoint convertedPoint = [self convertPoint:point toView:subview];
            if ([subview pointInside:convertedPoint withEvent:event])
                pointInside = true;
        }
    }
    return pointInside;
}

- (bool)isTrackingAnyEntityView
{
    bool tracking = false;
    for (TGPhotoPaintEntityView *view in self.subviews)
    {
        if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
            continue;
        
        if (view.isTracking)
        {
            tracking = true;
            break;
        }
    }
    return tracking;
}

@end
