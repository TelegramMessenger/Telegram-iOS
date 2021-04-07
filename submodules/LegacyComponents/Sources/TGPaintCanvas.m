#import "TGPaintCanvas.h"

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "matrix.h"

#import "TGPainting.h"
#import "TGPaintBuffers.h"
#import "TGPaintInput.h"
#import "TGPaintState.h"
#import "TGPaintShader.h"
#import <LegacyComponents/TGPaintUtils.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>

#import "TGPaintPanGestureRecognizer.h"

@interface TGPaintCanvas () <UIGestureRecognizerDelegate>
{
    TGPaintBuffers *_buffers;
    CGFloat _screenScale;
    CGAffineTransform _canvasTransform;
    CGRect _dirtyRect;
    
    CGRect _visibleRect;
    
    TGPaintInput *_input;
    TGPaintPanGestureRecognizer *_gestureRecognizer;
    bool _beganDrawing;
    
    __weak dispatch_cancelable_block_t _redrawBlock;
}
@end

@implementation TGPaintCanvas

- (instancetype)initWithFrame:(CGRect)frame
{
    _screenScale = MIN(2.0f, [UIScreen mainScreen].scale);
    
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.contentScaleFactor = _screenScale;
        self.multipleTouchEnabled = true;
        self.exclusiveTouch = true;
        
        _state = [[TGPaintState alloc] init];
        
        [self _setupGestureRecognizers];
    }
    return self;
}

#pragma mark - Painting

- (void)setPainting:(TGPainting *)painting
{
    _painting = painting;
    
    __weak TGPaintCanvas *weakSelf = self;
    painting.contentChanged = ^(CGRect rect)
    {
        __strong TGPaintCanvas *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (!CGRectEqualToRect(rect, CGRectZero))
            strongSelf->_dirtyRect = TGPaintUnionRect(strongSelf->_dirtyRect, rect);
        else
            strongSelf->_dirtyRect = [strongSelf visibleRect];
        
        [strongSelf _scheduleRedraw];
    };
    painting.strokeCommited = ^
    {
        __strong TGPaintCanvas *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf.strokeCommited != nil)
            strongSelf.strokeCommited();
    };
    
    [self setContext:painting.context];
    [self _updateTransform];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    _visibleRect = self.bounds;
    
    [self _updateTransform];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    
    _visibleRect = bounds;
}

- (void)_updateTransform
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    CGPoint center = TGPaintCenterOfRect(self.bounds);
    CGFloat scale = _painting ? self.bounds.size.width / _painting.size.width : 1.0f;
    if (scale < FLT_EPSILON)
        scale = 1.0f;
    
    transform = CGAffineTransformTranslate(transform, center.x, center.y);
    transform = CGAffineTransformScale(transform, scale, -scale);
    transform = CGAffineTransformTranslate(transform, -self.painting.size.width / 2, -self.painting.size.height / 2);
    
    _canvasTransform = transform;
    _input.transform = transform;
}

#pragma mark - Gesture

- (void)_setupGestureRecognizers
{
    _input = [[TGPaintInput alloc] init];
    
    _gestureRecognizer = [[TGPaintPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    _gestureRecognizer.delegate = self;
    _gestureRecognizer.minimumNumberOfTouches = 1;
    _gestureRecognizer.maximumNumberOfTouches = 2;
    
    __weak TGPaintCanvas *weakSelf = self;
    _gestureRecognizer.shouldRecognizeTap = ^bool
    {
        __strong TGPaintCanvas *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        if (strongSelf.shouldDrawOnSingleTap != nil)
        {
            bool drawOnTap = strongSelf.shouldDrawOnSingleTap();
            bool draw = strongSelf.shouldDraw();
            
            return draw && drawOnTap;
        }
        
        return false;
    };
    [self addGestureRecognizer:_gestureRecognizer];
}

- (void)handlePan:(TGPaintPanGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan || gestureRecognizer.state == UIGestureRecognizerStateChanged)
    {
        if (!_beganDrawing)
        {
            [_input gestureBegan:gestureRecognizer];
            if (self.strokeBegan != nil)
                self.strokeBegan();
            _beganDrawing = true;
        }
        else
        {
            [_input gestureMoved:gestureRecognizer];
        }
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded)
    {
        [_input gestureEnded:gestureRecognizer];
        _beganDrawing = false;
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled)
    {
        [_input gestureCanceled:gestureRecognizer];
        _beganDrawing = false;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (self.shouldDraw != nil)
        return self.shouldDraw();
    
    return true;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
//    if (gestureRecognizer == _gestureRecognizer && ([otherGestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]] || [otherGestureRecognizer isKindOfClass:[UIRotationGestureRecognizer class]]))
//        return false;
//
    return true;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    
    if (self.hitTest != nil)
    {
        UIView *maybeHitView = self.hitTest(point, event);
        if (maybeHitView != nil)
            view = maybeHitView;
    }
    
    return view;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)__unused event
{
    return self.pointInsideContainer(point);
}

- (bool)isTracking
{
    return (_gestureRecognizer.state == UIGestureRecognizerStateBegan || _gestureRecognizer.state == UIGestureRecognizerStateChanged);
}

#pragma mark - Draw

- (void)draw
{
    [self drawInRect:[self visibleRect]];
}

- (void)drawInRect:(CGRect)__unused rect
{
    [EAGLContext setCurrentContext:_buffers.context];
    
    glBindFramebuffer(GL_FRAMEBUFFER, _buffers.framebuffer);
    glViewport(0, 0, _buffers.width, _buffers.height);
    
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    GLfloat proj[16], effectiveProj[16], final[16];
    mat4f_LoadOrtho(0, (GLfloat)(_buffers.width / _screenScale), 0, (GLfloat)(_buffers.height / _screenScale), -1.0f, 1.0f, proj);
    mat4f_LoadCGAffineTransform(effectiveProj, _canvasTransform);
    mat4f_MultiplyMat4f(proj, effectiveProj, final);
    
    [_painting renderWithProjection:final];
    
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    [_buffers present];
    
    TGPaintHasGLError();
    
    _dirtyRect = CGRectZero;
}

- (void)redrawIfNeeded
{
    if (CGRectEqualToRect(_dirtyRect, CGRectZero))
        return;
    
    [self drawInRect:_dirtyRect];
}

- (void)_scheduleRedraw
{
    if (_redrawBlock != nil)
    {
        cancel_block(_redrawBlock);
        _redrawBlock = nil;
    }
    
    __weak TGPaintCanvas *weakSelf = self;
    _redrawBlock = dispatch_after_delay(0.0, [_painting _queue], ^
    {
        __strong TGPaintCanvas *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf redrawIfNeeded];
    });
}

#pragma mark - 

- (CGRect)visibleRect
{
    return _visibleRect;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self.painting performSynchronouslyInContext:^{
        [_buffers update];
        
        [self draw];
    }];
}

#pragma mark - GL Setup

- (void)setContext:(EAGLContext *)context
{
    if (context == _buffers.context)
        return;
    
    if (context != nil)
    {
        _buffers = [TGPaintBuffers buffersWithGLContext:context layer:(CAEAGLLayer *)self.layer];
        [_buffers update];
    }
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

#pragma mark -

- (void)setBrush:(TGPaintBrush *)brush
{
    _state.brush = brush;
    [_painting setBrush:brush];
}

- (void)setBrushWeight:(CGFloat)brushWeight
{
    _state.weight = brushWeight;
}

- (void)setBrushColor:(UIColor *)color
{
    _state.color = color;
}

- (void)setEraser:(bool)eraser
{
    _state.eraser = eraser;
}

@end
