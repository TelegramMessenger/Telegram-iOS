//
//  RMIntroViewController.h
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 19/01/14.
//
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
//#import "RMRootViewController.h"

typedef enum {
    Inch35 = 0,
    Inch4 = 1,
    Inch47 = 2,
    Inch55 = 3,
    iPad = 4,
    iPadPro = 5
} DeviceScreen;

@interface RMIntroViewController : UIViewController<UIScrollViewDelegate, GLKViewDelegate>
{
    EAGLContext *context;
    
    GLKView *_glkView;
    
    UIImageView *_startArrow;
    
    NSArray *_headlines;
    NSArray *_descriptions;
    
    NSMutableArray *_pageViews;
    
    NSInteger _currentPage;
    
    UIScrollView *_pageScrollView;
    UIButton *_startButton;
    UIPageControl *_pageControl;
    
    NSTimer *_updateAndRenderTimer;
    
    BOOL _isOpenGLLoaded;
}

@property (nonatomic, copy) void (^startMessaging)();

- (void)startTimer;
- (void)stopTimer;

@end
