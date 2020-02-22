#import "TGPhotoEditorBlurAreaView.h"

#import "TGPhotoEditorRadialBlurView.h"
#import "TGPhotoEditorLinearBlurView.h"

#import "PGBlurTool.h"

@interface TGPhotoEditorBlurAreaView () <UIGestureRecognizerDelegate>
{
    PGBlurToolType _type;
    
    TGPhotoEditorRadialBlurView *_radialBlurView;
    TGPhotoEditorLinearBlurView *_linearBlurView;
}
@end

@implementation TGPhotoEditorBlurAreaView

@synthesize actualAreaSize = _actualAreaSize;
@synthesize valueChanged = _valueChanged;
@synthesize value = _value;
@synthesize interactionEnded = _interactionEnded;
@synthesize isLandscape;
@synthesize toolbarLandscapeSize;

- (instancetype)initWithEditorItem:(id<PGPhotoEditorItem>)editorItem
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {        
        __weak TGPhotoEditorBlurAreaView *weakSelf = self;
        _radialBlurView = [[TGPhotoEditorRadialBlurView alloc] initWithFrame:self.bounds];
        _radialBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _radialBlurView.alpha = 0.0f;
        _radialBlurView.hidden = true;
        _radialBlurView.valueChanged = ^(CGPoint point, CGFloat falloff, CGFloat size)
        {
            __strong TGPhotoEditorBlurAreaView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf.valueChanged != nil)
            {
                PGBlurToolValue *value = [(PGBlurToolValue *)strongSelf.value copy];
                value.point = point;
                value.size = size;
                value.falloff = falloff;

                strongSelf.valueChanged(value, false);
            }
        };
        _radialBlurView.interactionEnded = ^
        {
            __strong TGPhotoEditorBlurAreaView *strongSelf = weakSelf;
            if (strongSelf != nil || strongSelf.interactionEnded != nil)
                strongSelf.interactionEnded();
        };
        [self addSubview:_radialBlurView];
        
        _linearBlurView = [[TGPhotoEditorLinearBlurView alloc] initWithFrame:self.bounds];
        _linearBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _linearBlurView.alpha = 0.0f;
        _linearBlurView.hidden = true;
        _linearBlurView.valueChanged = ^(CGPoint point, CGFloat falloff, CGFloat size, CGFloat angle)
        {
            __strong TGPhotoEditorBlurAreaView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf.valueChanged != nil)
            {
                PGBlurToolValue *value = [(PGBlurToolValue *)strongSelf.value copy];
                value.point = point;
                value.size = size;
                value.falloff = falloff;
                value.angle = angle;
                
                strongSelf.valueChanged(value, false);
            }
        };
        _linearBlurView.interactionEnded = ^
        {
            __strong TGPhotoEditorBlurAreaView *strongSelf = weakSelf;
            if (strongSelf != nil || strongSelf.interactionEnded != nil)
                strongSelf.interactionEnded();
        };
        [self addSubview:_linearBlurView];
        
        if ([editorItem isKindOfClass:[PGBlurTool class]])
            [self setValue:editorItem.value];
    }
    return self;
}

- (bool)buttonPressed:(bool)__unused cancelButton
{
    return false;
}

- (void)setActualAreaSize:(CGSize)actualAreaSize
{
    _actualAreaSize = actualAreaSize;
    
    _radialBlurView.actualAreaSize = actualAreaSize;
    _linearBlurView.actualAreaSize = actualAreaSize;
}

- (bool)isTracking
{
    return _radialBlurView.isTracking || _linearBlurView.isTracking;
}

#pragma mark - Value

- (void)setValue:(id)value
{
    _value = value;
    
    PGBlurToolValue *blurValue = (PGBlurToolValue *)value;
    
    _radialBlurView.centerPoint = blurValue.point;
    _radialBlurView.falloff = blurValue.falloff;
    _radialBlurView.size = blurValue.size;
    [_radialBlurView setNeedsDisplay];
    
    _linearBlurView.centerPoint = blurValue.point;
    _linearBlurView.falloff = blurValue.falloff;
    _linearBlurView.size = blurValue.size;
    _linearBlurView.angle = blurValue.angle;
    [_linearBlurView setNeedsDisplay];

    if (blurValue.type != _type)
    {
        _type = blurValue.type;
        
        if (_type == PGBlurToolTypeNone)
        {
            [UIView animateWithDuration:0.2f animations:^
            {
                _radialBlurView.alpha = 0.0f;
                _linearBlurView.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _radialBlurView.hidden = true;
                    _linearBlurView.hidden = true;
                }
            }];
        }
        else
        {
            _radialBlurView.hidden = false;
            _linearBlurView.hidden = false;
            
            [UIView animateWithDuration:0.2f animations:^
            {
                _radialBlurView.alpha = _type == PGBlurToolTypeRadial ? 1.0f : 0.0f;
                _linearBlurView.alpha = _type == PGBlurToolTypeLinear ? 1.0f : 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _radialBlurView.hidden = _type != PGBlurToolTypeRadial;
                    _linearBlurView.hidden = _type != PGBlurToolTypeLinear;
                }
            }];
        }
    }
}

@end
