#import "TGPhotoCropAreaView.h"

#import "LegacyComponentsInternal.h"

#import "TGPhotoCropGridView.h"

#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

#import "TGPhotoCropControl.h"

const CGSize TGPhotoCropCornerControlSize = { 44, 44 };
const CGFloat TGPhotoCropEdgeControlSize = 44;

@interface TGPhotoCropAreaView ()
{
    bool _isTracking;
    
    UIImageView *_cornersView;
    
    UIView *_topEdgeHighlight;
    UIView *_leftEdgeHighlight;
    UIView *_rightEdgeHighlight;
    UIView *_bottomEdgeHighlight;
    
    TGPhotoCropControl *_topLeftCornerControl;
    TGPhotoCropControl *_topRightCornerControl;
    TGPhotoCropControl *_bottomLeftCornerControl;
    TGPhotoCropControl *_bottomRightCornerControl;
    
    TGPhotoCropControl *_topEdgeControl;
    TGPhotoCropControl *_leftEdgeControl;
    TGPhotoCropControl *_bottomEdgeControl;
    TGPhotoCropControl *_rightEdgeControl;
    
    TGPhotoCropGridView *_majorGridView;
    TGPhotoCropGridView *_minorGridView;
}

@property (nonatomic, copy) bool(^shouldBeginResizing)(TGPhotoCropControl *sender);
@property (nonatomic, copy) void(^didBeginResizing)(TGPhotoCropControl *sender);
@property (nonatomic, copy) void(^didResize)(TGPhotoCropControl *sender, CGPoint translation);
@property (nonatomic, copy) void(^didEndResizing)(TGPhotoCropControl *sender);

@end

@implementation TGPhotoCropAreaView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        __weak TGPhotoCropAreaView *weakSelf = self;
        
        self.shouldBeginResizing = ^bool(__unused TGPhotoCropControl *sender)
        {
            __strong TGPhotoCropAreaView *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                if (strongSelf.shouldBeginEditing != nil)
                    return strongSelf.shouldBeginEditing();
            }
            
            return true;
        };
        
        self.didBeginResizing = ^(__unused TGPhotoCropControl *sender)
        {
            __strong TGPhotoCropAreaView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            strongSelf->_isTracking = true;
        
            if (strongSelf.didBeginEditing != nil)
                strongSelf.didBeginEditing();
            
            if (strongSelf->_lockAspectRatio)
                return;
            
            if (sender == strongSelf->_topEdgeControl)
                strongSelf->_topEdgeHighlight.hidden = false;
            else if (sender == strongSelf->_leftEdgeControl)
                strongSelf->_leftEdgeHighlight.hidden = false;
            else if (sender == strongSelf->_bottomEdgeControl)
                strongSelf->_bottomEdgeHighlight.hidden = false;
            else if (sender == strongSelf->_rightEdgeControl)
                strongSelf->_rightEdgeHighlight.hidden = false;
        };
        
        self.didResize = ^(TGPhotoCropControl *sender, CGPoint translation)
        {
            __strong TGPhotoCropAreaView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf handleResizeWithSender:sender translation:translation];
            
            if (strongSelf.areaChanged != nil)
                strongSelf.areaChanged();
        };
        
        self.didEndResizing = ^(TGPhotoCropControl *sender)
        {
            __strong TGPhotoCropAreaView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_isTracking = false;
            
            if (strongSelf.didEndEditing != nil)
                strongSelf.didEndEditing();
            
            if (strongSelf->_lockAspectRatio)
                return;
            
            if (sender == strongSelf->_topEdgeControl)
                strongSelf->_topEdgeHighlight.hidden = true;
            else if (sender == strongSelf->_leftEdgeControl)
                strongSelf->_leftEdgeHighlight.hidden = true;
            else if (sender == strongSelf->_bottomEdgeControl)
                strongSelf->_bottomEdgeHighlight.hidden = true;
            else if (sender == strongSelf->_rightEdgeControl)
                strongSelf->_rightEdgeHighlight.hidden = true;
        };
        
        self.hitTestEdgeInsets = UIEdgeInsetsMake(-16, -16, -16, -16);
        
        _cornersView = [[UIImageView alloc] initWithFrame:CGRectInset(self.bounds, -2, -2)];
        _cornersView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _cornersView.image = [TGComponentsImageNamed(@"PhotoEditorCropCorners") resizableImageWithCapInsets:UIEdgeInsetsMake(20, 20, 20, 20)];
        [self addSubview:_cornersView];
        
        _topEdgeHighlight = [[UIView alloc] initWithFrame:CGRectMake(0, -1, frame.size.width, 2)];
        _topEdgeHighlight.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _topEdgeHighlight.backgroundColor = [UIColor whiteColor];
        _topEdgeHighlight.hidden = true;
        [self addSubview:_topEdgeHighlight];
        
        _leftEdgeHighlight = [[UIView alloc] initWithFrame:CGRectMake(-1, 0, 2, frame.size.height)];
        _leftEdgeHighlight.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        _leftEdgeHighlight.backgroundColor = [UIColor whiteColor];
        _leftEdgeHighlight.hidden = true;
        [self addSubview:_leftEdgeHighlight];

        _rightEdgeHighlight = [[UIView alloc] initWithFrame:CGRectMake(frame.size.width - 1, 0, 2, frame.size.height)];
        _rightEdgeHighlight.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight;
        _rightEdgeHighlight.backgroundColor = [UIColor whiteColor];
        _rightEdgeHighlight.hidden = true;
        [self addSubview:_rightEdgeHighlight];
        
        _bottomEdgeHighlight = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height - 1, frame.size.width, 2)];
        _bottomEdgeHighlight.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        _bottomEdgeHighlight.backgroundColor = [UIColor whiteColor];
        _bottomEdgeHighlight.hidden = true;
        [self addSubview:_bottomEdgeHighlight];
        
        _topEdgeControl = [[TGPhotoCropControl alloc] initWithFrame:CGRectMake(TGPhotoCropCornerControlSize.width / 2,
                                                                               -TGPhotoCropEdgeControlSize / 2,
                                                                               frame.size.width - TGPhotoCropCornerControlSize.width,
                                                                               TGPhotoCropEdgeControlSize)];
        _topEdgeControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _topEdgeControl.hitTestEdgeInsets = UIEdgeInsetsMake(-16, 0, -16, 0);
        [self addSubview:_topEdgeControl];
        
        _leftEdgeControl = [[TGPhotoCropControl alloc] initWithFrame:CGRectMake(-TGPhotoCropEdgeControlSize / 2,
                                                                                TGPhotoCropCornerControlSize.height / 2,
                                                                                TGPhotoCropEdgeControlSize,
                                                                                frame.size.height - TGPhotoCropCornerControlSize.height)];
        _leftEdgeControl.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        _leftEdgeControl.hitTestEdgeInsets = UIEdgeInsetsMake(0, -16, 0, -16);
        [self addSubview:_leftEdgeControl];
        
        _bottomEdgeControl = [[TGPhotoCropControl alloc] initWithFrame:CGRectMake(TGPhotoCropCornerControlSize.width / 2,
                                                                                  frame.size.height - TGPhotoCropEdgeControlSize / 2,
                                                                                  frame.size.width - TGPhotoCropCornerControlSize.width,
                                                                                  TGPhotoCropEdgeControlSize)];
        _bottomEdgeControl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        _bottomEdgeControl.hitTestEdgeInsets = UIEdgeInsetsMake(-16, 0, -16, 0);
        [self addSubview:_bottomEdgeControl];
        
        _rightEdgeControl = [[TGPhotoCropControl alloc] initWithFrame:CGRectMake(frame.size.width - TGPhotoCropEdgeControlSize / 2,
                                                                                 TGPhotoCropCornerControlSize.height / 2,
                                                                                 TGPhotoCropEdgeControlSize,
                                                                                 frame.size.height - TGPhotoCropCornerControlSize.height)];
        _rightEdgeControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight;
        _rightEdgeControl.hitTestEdgeInsets = UIEdgeInsetsMake(0, -16, 0, -16);
        [self addSubview:_rightEdgeControl];
        
        _topLeftCornerControl = [[TGPhotoCropControl alloc] initWithFrame:CGRectMake(-TGPhotoCropCornerControlSize.width / 2,
                                                                                     -TGPhotoCropCornerControlSize.height / 2,
                                                                                     TGPhotoCropCornerControlSize.width,
                                                                                     TGPhotoCropCornerControlSize.height)];
        _topLeftCornerControl.hitTestEdgeInsets = UIEdgeInsetsMake(-16, -16, -16, -16);
        [self addSubview:_topLeftCornerControl];
        
        _topRightCornerControl = [[TGPhotoCropControl alloc] initWithFrame:CGRectMake(frame.size.width - TGPhotoCropCornerControlSize.width / 2,
                                                                                      -TGPhotoCropCornerControlSize.height / 2,
                                                                                      TGPhotoCropCornerControlSize.width,
                                                                                      TGPhotoCropCornerControlSize.height)];
        _topRightCornerControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _topRightCornerControl.hitTestEdgeInsets = UIEdgeInsetsMake(-16, -16, -16, -16);
        [self addSubview:_topRightCornerControl];
        
        _bottomLeftCornerControl = [[TGPhotoCropControl alloc] initWithFrame:CGRectMake(-TGPhotoCropCornerControlSize.width / 2,
                                                                                        frame.size.height - TGPhotoCropCornerControlSize.height / 2,
                                                                                        TGPhotoCropCornerControlSize.width,
                                                                                        TGPhotoCropCornerControlSize.height)];
        _bottomLeftCornerControl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        _bottomLeftCornerControl.hitTestEdgeInsets = UIEdgeInsetsMake(-16, -16, -16, -16);
        [self addSubview:_bottomLeftCornerControl];
        
        _bottomRightCornerControl = [[TGPhotoCropControl alloc] initWithFrame:CGRectMake(frame.size.width - TGPhotoCropCornerControlSize.width / 2,
                                                                                         frame.size.height - TGPhotoCropCornerControlSize.height / 2,
                                                                                         TGPhotoCropCornerControlSize.width,
                                                                                         TGPhotoCropCornerControlSize.height)];
        _bottomRightCornerControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        _bottomRightCornerControl.hitTestEdgeInsets = UIEdgeInsetsMake(-16, -16, -16, -16);
        [self addSubview:_bottomRightCornerControl];
        
        for (UIView *view in self.subviews)
        {
            if ([view isKindOfClass:[TGPhotoCropControl class]])
            {
                TGPhotoCropControl *control = (TGPhotoCropControl *)view;
                control.shouldBeginResizing = self.shouldBeginResizing;
                control.didBeginResizing = self.didBeginResizing;
                control.didResize = self.didResize;
                control.didEndResizing = self.didEndResizing;
            }
        }

        _majorGridView = [[TGPhotoCropGridView alloc] initWithMode:TGPhotoCropViewGridModeMajor];
        _majorGridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _majorGridView.frame = self.bounds;
        _majorGridView.hidden = true;
        [self addSubview:_majorGridView];
        
        _minorGridView = [[TGPhotoCropGridView alloc] initWithMode:TGPhotoCropViewGridModeMinor];
        _minorGridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _minorGridView.frame = self.bounds;
        _minorGridView.hidden = true;
        [self addSubview:_minorGridView];
    }
    return self;
}

- (bool)isTracking
{
    return _isTracking;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)__unused event
{
    UIView *view = [super hitTest:point withEvent:event];
    
    if ([view isKindOfClass:[TGPhotoCropControl class]])
        return view;

    return nil;
}

#pragma mark - Aspect Ratio

- (void)setAspectRatio:(CGFloat)aspectRatio
{
    _aspectRatio = aspectRatio;
}

- (void)setLockAspectRatio:(bool)lockAspectRatio
{
    _lockAspectRatio = lockAspectRatio;
    
    _topEdgeHighlight.hidden = !lockAspectRatio;
    _leftEdgeHighlight.hidden = !lockAspectRatio;
    _rightEdgeHighlight.hidden = !lockAspectRatio;
    _bottomEdgeHighlight.hidden = !lockAspectRatio;
}

#pragma mark - Grid

- (void)setGridMode:(TGPhotoCropViewGridMode)mode
{
    [self setGridMode:mode animated:false];
}

- (void)setGridMode:(TGPhotoCropViewGridMode)gridMode animated:(bool)animated
{
    if (_gridMode == gridMode)
        return;
    
    _gridMode = gridMode;
    
    switch (gridMode)
    {
        case TGPhotoCropViewGridModeMajor:
        {
            [self setGridView:_majorGridView hidden:false animated:animated];
            [self setGridView:_minorGridView hidden:true animated:animated];
        }
            break;
            
        case TGPhotoCropViewGridModeMinor:
        {
            [self setGridView:_majorGridView hidden:true animated:animated];
            [self setGridView:_minorGridView hidden:false animated:animated];
        }
            break;
            
        default:
        {
            [self setGridView:_majorGridView hidden:true animated:animated];
            [self setGridView:_minorGridView hidden:true animated:animated];
        }
            break;
    }
}

- (void)setGridView:(TGPhotoCropGridView *)gridView hidden:(bool)hidden animated:(bool)animated
{
    if (animated)
        [gridView setHidden:hidden animated:true duration:0.2f delay:0.0f];
    else
        gridView.hidden = hidden;
}

#pragma mark - Resize

- (void)handleResizeWithSender:(TGPhotoCropControl *)sender translation:(CGPoint)translation
{
    CGRect rect = self.frame;
    
    if (sender == _topLeftCornerControl)
    {
        rect = CGRectMake(self.frame.origin.x + translation.x,
                          self.frame.origin.y + translation.y,
                          self.frame.size.width - translation.x,
                          self.frame.size.height - translation.y);
        
        if (self.lockAspectRatio)
        {
            CGRect constrainedRect = [self constrainedRectFromRectWithWidth:rect aspectRatio:self.aspectRatio];
            if (ABS(translation.x) < ABS(translation.y))
                constrainedRect = [self constrainedRectFromRectWithHeight:rect aspectRatio:self.aspectRatio];
        
            constrainedRect.origin.x -= constrainedRect.size.width - rect.size.width;
            constrainedRect.origin.y -= constrainedRect.size.height - rect.size.height;
            
            rect = constrainedRect;
        }
    }
    else if (sender == _topRightCornerControl)
    {
        rect = CGRectMake(self.frame.origin.x,
                          self.frame.origin.y + translation.y,
                          self.frame.size.width + translation.x,
                          self.frame.size.height - translation.y);
        
        if (self.lockAspectRatio)
        {
            CGRect constrainedRect = [self constrainedRectFromRectWithWidth:rect aspectRatio:self.aspectRatio];
            if (ABS(translation.x) < ABS(translation.y))
                constrainedRect = [self constrainedRectFromRectWithHeight:rect aspectRatio:self.aspectRatio];
            
            constrainedRect.origin.y -= constrainedRect.size.height - rect.size.height;
            
            rect = constrainedRect;
        }
    }
    else if (sender == _bottomLeftCornerControl)
    {
        rect = CGRectMake(self.frame.origin.x + translation.x,
                          self.frame.origin.y,
                          self.frame.size.width - translation.x,
                          self.frame.size.height + translation.y);
        
        if (self.lockAspectRatio)
        {
            CGRect constrainedRect;
            if (ABS(translation.x) < ABS(translation.y))
                constrainedRect = [self constrainedRectFromRectWithHeight:rect aspectRatio:self.aspectRatio];
            else
                constrainedRect = [self constrainedRectFromRectWithWidth:rect aspectRatio:self.aspectRatio];
            
            constrainedRect.origin.x -= constrainedRect.size.width - rect.size.width;
            
            rect = constrainedRect;
        }
    }
    else if (sender == _bottomRightCornerControl)
    {
        rect = CGRectMake(self.frame.origin.x,
                          self.frame.origin.y,
                          self.frame.size.width + translation.x,
                          self.frame.size.height + translation.y);
        
        if (self.lockAspectRatio)
        {
            if (ABS(translation.x) < ABS(translation.y))
                rect = [self constrainedRectFromRectWithHeight:rect aspectRatio:self.aspectRatio];
            else
                rect = [self constrainedRectFromRectWithWidth:rect aspectRatio:self.aspectRatio];
        }
    }
    else if (sender == _topEdgeControl)
    {
        rect = CGRectMake(self.frame.origin.x,
                          self.frame.origin.y + translation.y,
                          self.frame.size.width,
                          self.frame.size.height - translation.y);
        
        if (self.lockAspectRatio)
            rect = [self constrainedRectFromRectWithHeight:rect aspectRatio:self.aspectRatio];
    }
    else if (sender == _leftEdgeControl)
    {
        rect = CGRectMake(self.frame.origin.x + translation.x,
                          self.frame.origin.y,
                          self.frame.size.width - translation.x,
                          self.frame.size.height);
        
        if (self.lockAspectRatio)
            rect = [self constrainedRectFromRectWithWidth:rect aspectRatio:self.aspectRatio];
    }
    else if (sender == _bottomEdgeControl)
    {
        rect = CGRectMake(self.frame.origin.x,
                          self.frame.origin.y,
                          self.frame.size.width,
                          self.frame.size.height + translation.y);
        
        if (self.lockAspectRatio)
            rect = [self constrainedRectFromRectWithHeight:rect aspectRatio:self.aspectRatio];
    }
    else if (sender == _rightEdgeControl)
    {
        rect = CGRectMake(self.frame.origin.x,
                          self.frame.origin.y,
                          self.frame.size.width + translation.x,
                          self.frame.size.height);
        
        if (self.lockAspectRatio)
            rect = [self constrainedRectFromRectWithWidth:rect aspectRatio:self.aspectRatio];
    }
    
    CGFloat minimumWidth = TGPhotoCropCornerControlSize.width;
    if (rect.size.width < minimumWidth)
        rect.size.width = minimumWidth;
    
    CGFloat minimumHeight = TGPhotoCropCornerControlSize.height;
    if (rect.size.height < minimumHeight)
        rect.size.height = minimumHeight;
    
    if (self.lockAspectRatio)
    {
        CGRect constrainedRect = rect;
        
        if (self.aspectRatio > 1)
        {
            if (rect.size.width <= minimumWidth)
            {
                constrainedRect.size.width = minimumWidth;
                constrainedRect.size.height = constrainedRect.size.width * self.aspectRatio;
            }
        }
        else
        {
            if (rect.size.height <= minimumHeight)
            {
                constrainedRect.size.height = minimumHeight;
                constrainedRect.size.width = constrainedRect.size.height / self.aspectRatio;
            }
        }

        rect = constrainedRect;
    }
    
    self.frame = rect;
}

- (CGRect)constrainedRectFromRectWithWidth:(CGRect)rect aspectRatio:(CGFloat)aspectRatio
{
    CGFloat width = rect.size.width;
    CGFloat height = width * aspectRatio;

    rect.size = CGSizeMake(width, height);
    
    return rect;
}

- (CGRect)constrainedRectFromRectWithHeight:(CGRect)rect aspectRatio:(CGFloat)aspectRatio
{
    CGFloat height = rect.size.height;
    CGFloat width = height / aspectRatio;

    rect.size = CGSizeMake(width, height);
    
    return rect;
}

@end
