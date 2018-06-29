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

@class SSignal;

@interface TGAvailableLocalization : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *localizedTitle;
@property (nonatomic, strong, readonly) NSString *code;

- (instancetype)initWithTitle:(NSString *)title localizedTitle:(NSString *)localizedTitle code:(NSString *)code;

@end

@interface TGSuggestedLocalization : NSObject

@property (nonatomic, strong, readonly) TGAvailableLocalization *info;
@property (nonatomic, strong, readonly) NSString *continueWithLanguageString;
@property (nonatomic, strong, readonly) NSString *chooseLanguageString;
@property (nonatomic, strong, readonly) NSString *chooseLanguageOtherString;
@property (nonatomic, strong, readonly) NSString *englishLanguageNameString;

- (instancetype)initWithInfo:(TGAvailableLocalization *)info continueWithLanguageString:(NSString *)continueWithLanguageString chooseLanguageString:(NSString *)chooseLanguageString chooseLanguageOtherString:(NSString *)chooseLanguageOtherString englishLanguageNameString:(NSString *)englishLanguageNameString;

@end

@interface RMIntroViewController : UIViewController<UIScrollViewDelegate, GLKViewDelegate>
{
    EAGLContext *context;
    
    GLKView *_glkView;
    
    NSArray *_headlines;
    NSArray *_descriptions;
    
    NSMutableArray *_pageViews;
    
    NSInteger _currentPage;
    
    UIScrollView *_pageScrollView;
    UIPageControl *_pageControl;
    
    NSTimer *_updateAndRenderTimer;
    
    BOOL _isOpenGLLoaded;
}

- (instancetype)initWithBackroundColor:(UIColor *)backgroundColor primaryColor:(UIColor *)primaryColor accentColor:(UIColor *)accentColor regularDotColor:(UIColor *)regularDotColor highlightedDotColor:(UIColor *)highlightedDotColor suggestedLocalizationSignal:(SSignal *)suggestedLocalizationSignal;

@property (nonatomic, copy) void (^startMessaging)(void);
@property (nonatomic, copy) void (^startMessagingInAlternativeLanguage)(NSString *);

@property (nonatomic) bool isEnabled;

- (void)startTimer;
- (void)stopTimer;

@end
