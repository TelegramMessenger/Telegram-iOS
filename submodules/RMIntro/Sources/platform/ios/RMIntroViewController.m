//
//  RMIntroViewController.m
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 19/01/14.
//
//

#import "RMGeometry.h"

#import "RMIntroViewController.h"
#import "RMIntroPageView.h"

#include "animations.h"
#include "objects.h"
#include "texture_helper.h"

#import <SSignalKit/SSignalKit.h>

#import <LegacyComponents/LegacyComponents.h>

typedef enum {
    Inch35 = 0,
    Inch4 = 1,
    Inch47 = 2,
    Inch55 = 3,
    Inch65 = 4,
    iPad = 5,
    iPadPro = 6
} DeviceScreen;

@interface UIScrollView (CurrentPage)
- (int)currentPage;
- (void)setPage:(NSInteger)page;
- (int)currentPageMin;
- (int)currentPageMax;

@end

@implementation UIScrollView (CurrentPage)

- (int)currentPage
{
    CGFloat pageWidth = self.frame.size.width;
    return (int)floor((self.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
}

- (int)currentPageMin
{
    CGFloat pageWidth = self.frame.size.width;
    return (int)floor((self.contentOffset.x - pageWidth / 2 - pageWidth / 2) / pageWidth) + 1;
}

- (int)currentPageMax
{
    CGFloat pageWidth = self.frame.size.width;
    return (int)floor((self.contentOffset.x - pageWidth / 2 + pageWidth / 2 ) / pageWidth) + 1;
}

- (void)setPage:(NSInteger)page
{
    self.contentOffset = CGPointMake(self.frame.size.width*page, 0);
}
@end

@interface RMIntroView : UIView

@property (nonatomic, copy) void (^onLayout)();

@end

@implementation RMIntroView

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (_onLayout) {
        _onLayout();
    }
}

@end

@interface RMIntroViewController () <UIGestureRecognizerDelegate>
{
    id _didEnterBackgroundObserver;
    id _willEnterBackgroundObserver;
    
    UIColor *_backgroundColor;
    UIColor *_primaryColor;
    UIColor *_buttonColor;
    UIColor *_accentColor;
    UIColor *_regularDotColor;
    UIColor *_highlightedDotColor;
    
    TGModernButton *_alternativeLanguageButton;
    
    SMetaDisposable *_localizationsDisposable;
    TGSuggestedLocalization *_alternativeLocalizationInfo;
    
    SVariable *_alternativeLocalization;
    NSDictionary<NSString *, NSString *> *_englishStrings;
    
    UIView *_wrapperView;
    
    bool _loadedView;
}
@end


@implementation RMIntroViewController

- (instancetype)initWithBackgroundColor:(UIColor *)backgroundColor primaryColor:(UIColor *)primaryColor buttonColor:(UIColor *)buttonColor accentColor:(UIColor *)accentColor regularDotColor:(UIColor *)regularDotColor highlightedDotColor:(UIColor *)highlightedDotColor suggestedLocalizationSignal:(SSignal *)suggestedLocalizationSignal
{
    self = [super init];
    if (self != nil)
    {
        _isEnabled = true;
        
        _backgroundColor = backgroundColor;
        _primaryColor = primaryColor;
        _buttonColor = buttonColor;
        _accentColor = accentColor;
        _regularDotColor = regularDotColor;
        _highlightedDotColor = highlightedDotColor;
        
        self.automaticallyAdjustsScrollViewInsets = false;
        
        NSArray<NSString *> *stringKeys = @[
            @"Tour.Title1",
            @"Tour.Title2",
            @"Tour.Title3",
            @"Tour.Title4",
            @"Tour.Title5",
            @"Tour.Title6",
            @"Tour.Text1",
            @"Tour.Text2",
            @"Tour.Text3",
            @"Tour.Text4",
            @"Tour.Text5",
            @"Tour.Text6",
            @"Tour.StartButton"
        ];
        
        NSMutableDictionary *englishStrings = [[NSMutableDictionary alloc] init];
        NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"en" ofType:@"lproj"]];
        for (NSString *key in stringKeys) {
            if (bundle != nil) {
                NSString *value = [bundle localizedStringForKey:key value:key table:nil];
                if (value != nil) {
                    englishStrings[key] = value;
                } else {
                    englishStrings[key] = key;
                }
            } else {
                englishStrings[key] = key;
            }
        }
        _englishStrings = englishStrings;
        
        _headlines = @[ _englishStrings[@"Tour.Title1"], _englishStrings[@"Tour.Title2"],  _englishStrings[@"Tour.Title6"], _englishStrings[@"Tour.Title3"], _englishStrings[@"Tour.Title4"], _englishStrings[@"Tour.Title5"]];
        _descriptions = @[_englishStrings[@"Tour.Text1"], _englishStrings[@"Tour.Text2"],  _englishStrings[@"Tour.Text6"], _englishStrings[@"Tour.Text3"], _englishStrings[@"Tour.Text4"], _englishStrings[@"Tour.Text5"]];
        
        __weak RMIntroViewController *weakSelf = self;
        _didEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *notification)
        {
            __strong RMIntroViewController *strongSelf = weakSelf;
            [strongSelf stopTimer];
        }];
        
        _willEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *notification)
        {
            __strong RMIntroViewController *strongSelf = weakSelf;
            [strongSelf loadGL];
            [strongSelf startTimer];
        }];
        
        _alternativeLanguageButton = [[TGModernButton alloc] init];
        _alternativeLanguageButton.modernHighlight = true;
        [_alternativeLanguageButton setTitleColor:accentColor];
        
        _alternativeLanguageButton.titleLabel.font = [UIFont systemFontOfSize:18.0];
        _alternativeLanguageButton.hidden = true;
        [_alternativeLanguageButton addTarget:self action:@selector(alternativeLanguageButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _alternativeLocalization = [[SVariable alloc] init];
        
        _localizationsDisposable = [[suggestedLocalizationSignal deliverOn:[SQueue mainQueue]] startWithNext:^(TGSuggestedLocalization *next) {
            __strong RMIntroViewController *strongSelf = weakSelf;
            if (strongSelf != nil && next != nil) {
                if (strongSelf->_alternativeLocalizationInfo == nil) {
                    strongSelf->_alternativeLocalizationInfo = next;
                    
                    [strongSelf->_alternativeLanguageButton setTitle:next.continueWithLanguageString forState:UIControlStateNormal];
                    strongSelf->_alternativeLanguageButton.hidden = false;
                    [strongSelf->_alternativeLanguageButton sizeToFit];
                    
                    if ([strongSelf isViewLoaded]) {
                        strongSelf->_alternativeLanguageButton.alpha = 0.0;
                        [UIView animateWithDuration:0.3 animations:^{
                            strongSelf->_alternativeLanguageButton.alpha = strongSelf->_isEnabled ? 1.0 : 0.6;
                            [strongSelf viewWillLayoutSubviews];
                        }];
                    }
                }
            }
        }];
    }
    return self;
}

- (void)startTimer
{
    if (_updateAndRenderTimer == nil)
    {
        _updateAndRenderTimer = [NSTimer timerWithTimeInterval:1.0f / 60.0f target:self selector:@selector(updateAndRender) userInfo:nil repeats:true];
        [[NSRunLoop mainRunLoop] addTimer:_updateAndRenderTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)stopTimer
{
    if (_updateAndRenderTimer != nil)
    {
        [_updateAndRenderTimer invalidate];
        _updateAndRenderTimer = nil;
    }
}

- (void)loadGL
{
#if TARGET_OS_SIMULATOR && defined(__aarch64__)
    return;
#endif
    
    if (/*[[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground*/true && !_isOpenGLLoaded)
    {
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!_context)
            NSLog(@"Failed to create ES context");
        
        bool isIpad = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad);
        
        CGFloat size = 200;
        if (isIpad)
            size *= 1.2;
        
        int height = 50;
        if (isIpad)
            height += 138 / 2;
        
        _glkView = [[GLKView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width / 2 - size / 2, height, size, size) context:_context];
        _glkView.backgroundColor = _backgroundColor;
        _glkView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _glkView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
        _glkView.drawableMultisample = GLKViewDrawableMultisample4X;
        _glkView.enableSetNeedsDisplay = false;
        _glkView.userInteractionEnabled = false;
        _glkView.delegate = self;
        
        [self setupGL];
        [self.view addSubview:_glkView];
        
        [self startTimer];
        _isOpenGLLoaded = true;
    }
}

- (void)freeGL
{
    if (!_isOpenGLLoaded)
        return;

    [self stopTimer];
    
    if ([EAGLContext currentContext] == _glkView.context)
        [EAGLContext setCurrentContext:nil];

    _glkView.context = nil;
    _context = nil;
    [_glkView removeFromSuperview];
    _glkView = nil;
    _isOpenGLLoaded = false;
}

- (void)loadView {
    self.view = [[RMIntroView alloc] initWithFrame:self.defaultFrame];
    __weak RMIntroViewController *weakSelf = self;
    ((RMIntroView *)self.view).onLayout = ^{
        __strong RMIntroViewController *strongSelf = weakSelf;
        if (strongSelf != nil) {
            [strongSelf updateLayout];
        }
    };
    
    [self viewDidLoad];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (_loadedView) {
        return;
    }
    _loadedView = true;
    
    self.view.backgroundColor = _backgroundColor;
    
    [self loadGL];
    
    _wrapperView = [[UIScrollView alloc]initWithFrame:self.view.bounds];
    [self.view addSubview:_wrapperView];
    
    _pageScrollView = [[UIScrollView alloc]initWithFrame:self.view.bounds];
    _pageScrollView.clipsToBounds = true;
    _pageScrollView.opaque = true;
    _pageScrollView.clearsContextBeforeDrawing = false;
    [_pageScrollView setShowsHorizontalScrollIndicator:false];
    [_pageScrollView setShowsVerticalScrollIndicator:false];
    _pageScrollView.pagingEnabled = true;
    _pageScrollView.contentSize = CGSizeMake(_headlines.count * self.view.bounds.size.width, self.view.bounds.size.height);
    _pageScrollView.delegate = self;
    [_wrapperView addSubview:_pageScrollView];
    
    _pageViews = [NSMutableArray array];
    
    for (NSUInteger i = 0; i < _headlines.count; i++)
    {
        RMIntroPageView *p = [[RMIntroPageView alloc]initWithFrame:CGRectMake(i * self.view.bounds.size.width, 0, self.view.bounds.size.width, 0) headline:[_headlines objectAtIndex:i] description:[_descriptions objectAtIndex:i] color:_primaryColor];
        p.opaque = true;
        p.clearsContextBeforeDrawing = false;
        [_pageViews addObject:p];
        [_pageScrollView addSubview:p];
    }
    [_pageScrollView setPage:0];
    
    [self.view addSubview:_alternativeLanguageButton];
    
    _pageControl = [[UIPageControl alloc] init];
    _pageControl.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
    _pageControl.userInteractionEnabled = false;
    [_pageControl setNumberOfPages:6];
    _pageControl.pageIndicatorTintColor = _regularDotColor;
    _pageControl.currentPageIndicatorTintColor = _highlightedDotColor;
    [_wrapperView addSubview:_pageControl];
}

- (UIView *)createAnimationSnapshot {
    UIImage *image = _glkView.snapshot;
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:_glkView.frame];
    imageView.image = image;
    return imageView;
}

- (UIView *)createTextSnapshot {
    UIView *snapshotView = [_wrapperView snapshotViewAfterScreenUpdates:false];
    snapshotView.frame = _wrapperView.frame;
    return snapshotView;
}

- (BOOL)shouldAutorotate
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        return true;
    
    return false;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        return UIInterfaceOrientationMaskAll;
    
    return UIInterfaceOrientationMaskPortrait;
}

- (DeviceScreen)deviceScreen
{
    CGSize viewSize = self.view.frame.size;
    int max = (int)MAX(viewSize.width, viewSize.height);
    
    DeviceScreen deviceScreen = Inch55;
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        switch (max)
        {
            case 1366:
                deviceScreen = iPadPro;
                break;
                
            default:
                deviceScreen = iPad;
                break;
        }
    }
    else
    {
        switch (max)
        {
            case 480:
                deviceScreen = Inch35;
                break;
            case 568:
                deviceScreen = Inch4;
                break;
            case 667:
                deviceScreen = Inch47;
                break;
            case 896:
                deviceScreen = Inch65;
                break;
            default:
                deviceScreen = Inch55;
                break;
        }
    }
    
    return deviceScreen;
}

- (void)updateLayout
{
    UIInterfaceOrientation isVertical = (self.view.bounds.size.height / self.view.bounds.size.width > 1.0f);
    
    CGFloat statusBarHeight = 0;
    
    CGFloat pageControlY = 0;
    CGFloat glViewY = 0;
    CGFloat startButtonY = 0;
    CGFloat pageY = 0;
    
    CGFloat languageButtonSpread = 60.0f;
    CGFloat languageButtonOffset = 26.0f;
    
    DeviceScreen deviceScreen = [self deviceScreen];
    switch (deviceScreen)
    {
        case iPad:
            glViewY = isVertical ? 121 + 90 : 121;
            startButtonY = 120;
            pageY = isVertical ? 485 : 335;
            pageControlY = pageY + 200.0f;
            break;
            
        case iPadPro:
            glViewY = isVertical ? 221 + 110 : 221;
            startButtonY = 120;
            pageY = isVertical ? 605 : 435;
            pageControlY = pageY + 200.0f;
            break;
            
        case Inch35:
            pageControlY = 162 / 2;
            glViewY = 62 - 20;
            startButtonY = 75;
            pageY = 215;
            pageControlY = pageY + 160.0f;
            if (!_alternativeLanguageButton.isHidden) {
                glViewY -= 40.0f;
                pageY -= 40.0f;
                pageControlY -= 40.0f;
                startButtonY -= 30.0f;
            }
            languageButtonSpread = 65.0f;
            languageButtonOffset = 15.0f;
            break;
            
        case Inch4:
            glViewY = 62;
            startButtonY = 75;
            pageY = 245;
            pageControlY = pageY + 160.0f;
            languageButtonSpread = 50.0f;
            languageButtonOffset = 20.0f;
            break;
            
        case Inch47:
            pageControlY = 162 / 2 + 10;
            glViewY = 62 + 25;
            startButtonY = 75 + 5;
            pageY = 245 + 50;
            pageControlY = pageY + 160.0f;
            break;
            
        case Inch55:
            glViewY = 62 + 45;
            startButtonY = 75 + 20;
            pageY = 245 + 85;
            pageControlY = pageY + 160.0f;
            break;
            
        case Inch65:
            glViewY = 62 + 85;
            startButtonY = 75 + 30;
            pageY = 245 + 125;
            pageControlY = pageY + 160.0f;
            break;
            
        default:
            break;
    }
    
    if (!_alternativeLanguageButton.isHidden) {
        startButtonY += languageButtonSpread;
    }
    
    _pageControl.frame = CGRectMake(0, pageControlY, self.view.bounds.size.width, 7);
    _glkView.frame = CGRectChangedOriginY(_glkView.frame, glViewY - statusBarHeight);
    
    CGFloat startButtonWidth = self.view.bounds.size.width - 48.0f;
    UIView *startButton = self.createStartButton(startButtonWidth);
    if (startButton.superview == nil) {
        [self.view addSubview:startButton];
    }
    startButton.frame = CGRectMake(floor((self.view.bounds.size.width - startButtonWidth) / 2.0f), self.view.bounds.size.height - startButtonY - statusBarHeight, startButtonWidth, 50.0f);
    
    _alternativeLanguageButton.frame = CGRectMake(floor((self.view.bounds.size.width - _alternativeLanguageButton.frame.size.width) / 2.0f), CGRectGetMaxY(startButton.frame) + languageButtonOffset, _alternativeLanguageButton.frame.size.width, _alternativeLanguageButton.frame.size.height);
    
    _wrapperView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    _pageScrollView.frame=CGRectMake(0, 20, self.view.bounds.size.width, self.view.bounds.size.height - 20);
    _pageScrollView.contentSize=CGSizeMake(_headlines.count * self.view.bounds.size.width, 150);
    _pageScrollView.contentOffset = CGPointMake(_currentPage * self.view.bounds.size.width, 0);
    
    [_pageViews enumerateObjectsUsingBlock:^(UIView *pageView, NSUInteger index, __unused BOOL *stop)
     {
         pageView.frame = CGRectMake(index * self.view.bounds.size.width, (pageY - statusBarHeight), self.view.bounds.size.width, 150);
     }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self loadGL];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self freeGL];
}

- (void)startButtonPress
{
    if (_startMessaging) {
        _startMessaging();
    }
}

- (void)updateAndRender
{
    [_glkView display];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:_didEnterBackgroundObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:_willEnterBackgroundObserver];
    
    [self freeGL];
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:_glkView.context];
    
    UIColor *color = _backgroundColor;
    
    CGFloat red = 0.0f;
    CGFloat green = 0.0f;
    CGFloat blue = 0.0f;
    if ([color getRed:&red green:&green blue:&blue alpha:NULL]) {
    } else if ([color getWhite:&red alpha:NULL]) {
        green = red;
        blue = red;
    }
    set_intro_background_color(red, green, blue);
    
    set_telegram_textures(setup_texture(@"telegram_sphere.png", color), setup_texture(@"telegram_plane1.png", color));
    
    set_ic_textures(setup_texture(@"ic_bubble_dot.png", color), setup_texture(@"ic_bubble.png", color), setup_texture(@"ic_cam_lens.png", color), setup_texture(@"ic_cam.png", color), setup_texture(@"ic_pencil.png", color), setup_texture(@"ic_pin.png", color), setup_texture(@"ic_smile_eye.png", color), setup_texture(@"ic_smile.png", color), setup_texture(@"ic_videocam.png", color));
    
    set_fast_textures(setup_texture(@"fast_body.png", color), setup_texture(@"fast_spiral.png", color), setup_texture(@"fast_arrow.png", color), setup_texture(@"fast_arrow_shadow.png", color));
    
    set_free_textures(setup_texture(@"knot_up1.png", color), setup_texture(@"knot_down.png", color));
    
    set_powerful_textures(setup_texture(@"powerful_mask.png", color), setup_texture(@"powerful_star.png", color), setup_texture(@"powerful_infinity.png", color), setup_texture(@"powerful_infinity_white.png", color));
    
    set_private_textures(setup_texture(@"private_door.png", color), setup_texture(@"private_screw.png", color));
    
    on_surface_created();
    on_surface_changed(200, 200, 1, 0,0,0,0,0);
}

#pragma mark - GLKView delegate methods

- (void)glkView:(GLKView *)__unused view drawInRect:(CGRect)__unused rect
{
    double time = CFAbsoluteTimeGetCurrent();
    
    set_page((int)_currentPage);
    set_date(time);
    
    on_draw_frame();
}

static CGFloat x;
static bool justEndDragging;

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)__unused decelerate
{
    x = scrollView.contentOffset.x;
    justEndDragging = true;
}

NSInteger _current_page_end;

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat offset = (scrollView.contentOffset.x - _currentPage * scrollView.frame.size.width) / self.view.frame.size.width;
    
    set_scroll_offset((float)offset);
    
    if (justEndDragging)
    {
        justEndDragging = false;
        
        CGFloat page = scrollView.contentOffset.x / scrollView.frame.size.width;
        CGFloat sign = scrollView.contentOffset.x - x;
        
        if (sign > 0)
        {
            if (page > _currentPage)
                _currentPage++;
        }
        
        if (sign < 0)
        {
            if (page < _currentPage)
                _currentPage--;
        }
        
        _currentPage = MAX(0, MIN(5, _currentPage));
        _current_page_end = _currentPage;
    }
    else
    {
        if (_pageScrollView.contentOffset.x > _current_page_end*_pageScrollView.frame.size.width)
        {
            if (_pageScrollView.currentPageMin > _current_page_end) {
                _currentPage = [_pageScrollView currentPage];
                _current_page_end = _currentPage;
            }
        }
        else
        {
            if (_pageScrollView.currentPageMax < _current_page_end)
            {
                _currentPage = [_pageScrollView currentPage];
                _current_page_end = _currentPage;
            }
        }
    }
    
    [_pageControl setCurrentPage:_currentPage];
}

- (void)alternativeLanguageButtonPressed {
    if (_startMessagingInAlternativeLanguage && _alternativeLocalizationInfo.info.code.length != 0) {
        _startMessagingInAlternativeLanguage(_alternativeLocalizationInfo.info.code);
    }
}

- (void)setIsEnabled:(bool)isEnabled {
    if (_isEnabled != isEnabled) {
        _isEnabled = isEnabled;
        _alternativeLanguageButton.alpha = _isEnabled ? 1.0 : 0.6;
    }
}

@end

@implementation TGAvailableLocalization

- (instancetype)initWithTitle:(NSString *)title localizedTitle:(NSString *)localizedTitle code:(NSString *)code {
    self = [super init];
    if (self != nil) {
        _title = title;
        _localizedTitle = localizedTitle;
        _code = code;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithTitle:[aDecoder decodeObjectForKey:@"title"] localizedTitle:[aDecoder decodeObjectForKey:@"localizedTitle"] code:[aDecoder decodeObjectForKey:@"code"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_title forKey:@"title"];
    [aCoder encodeObject:_localizedTitle forKey:@"localizedTitle"];
    [aCoder encodeObject:_code forKey:@"code"];
}

@end

@implementation TGSuggestedLocalization

- (instancetype)initWithInfo:(TGAvailableLocalization *)info continueWithLanguageString:(NSString *)continueWithLanguageString chooseLanguageString:(NSString *)chooseLanguageString chooseLanguageOtherString:(NSString *)chooseLanguageOtherString englishLanguageNameString:(NSString *)englishLanguageNameString {
    self = [super init];
    if (self != nil) {
        _info = info;
        _continueWithLanguageString = continueWithLanguageString;
        _chooseLanguageString = chooseLanguageString;
        _chooseLanguageOtherString = chooseLanguageOtherString;
        _englishLanguageNameString = englishLanguageNameString;
    }
    return self;
}

@end
