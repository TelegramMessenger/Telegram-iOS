//
//  RMGLKViewController.m
//  Intro
//
//  Created by Ilya on 04/03/14.
//
//

#import "RMGLKViewController.h"
#include "game.h"

@interface RMGLKViewController () {
}

@property (strong, nonatomic) EAGLContext *context;

- (void)setupGL;

@end

@implementation RMGLKViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    //view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    //view.drawableStencilFormat = GLKViewDrawableStencilFormat8;
    //view.userInteractionEnabled = YES;
    self.preferredFramesPerSecond = 60;
    
    [self setupGL];
}

- (void)dealloc
{
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    on_surface_created();
    
    on_surface_changed(self.view.bounds.size.width, self.view.bounds.size.height);
    //on_surface_changed(240*self.view.contentScaleFactor, 240*self.view.contentScaleFactor);
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    on_draw_frame();
}

@end
