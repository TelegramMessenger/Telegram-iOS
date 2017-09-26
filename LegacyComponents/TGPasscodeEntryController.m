#import "TGPasscodeEntryController.h"

#import "TGPasswordEntryView.h"

#import "TGStringUtils.h"

#import "TGTimerTarget.h"
#import "TGObserverProxy.h"

#import <AudioToolbox/AudioToolbox.h>
#import <LocalAuthentication/LocalAuthentication.h>

#import "LegacyComponentsInternal.h"

typedef enum {
    TGPasscodeEntryControllerSubmodeEnteringCurrent,
    TGPasscodeEntryControllerSubmodeEnteringNew,
    TGPasscodeEntryControllerSubmodeReenteringNew
} TGPasscodeEntryControllerSubmode;

@implementation TGPasscodeEntryAttemptData

- (instancetype)initWithNumberOfInvalidAttempts:(NSInteger)numberOfInvalidAttempts dateOfLastInvalidAttempt:(double)dateOfLastInvalidAttempt {
    self = [super init];
    if (self != nil) {
        _numberOfInvalidAttempts = numberOfInvalidAttempts;
        _dateOfLastInvalidAttempt = dateOfLastInvalidAttempt;
    }
    return self;
}

@end

@interface TGPasscodeEntryController ()
{
    TGPasscodeEntryControllerStyle _style;
    TGPasscodeEntryControllerMode _mode;
    TGPasscodeEntryControllerSubmode _submode;
    bool _cancelEnabled;
    
    NSString *_candidatePasscode;
    
    TGPasswordEntryView *_view;
    
    UIBarButtonItem *_nextItem;
    bool _usingTouchId;
    bool _alternativeMethodSelected;
    
    NSTimer *_shouldWaitTimer;
    bool _keepStatusBarStyle;
    
    TGPasscodeEntryAttemptData *_attemptData;
}

@end

@implementation TGPasscodeEntryController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context style:(TGPasscodeEntryControllerStyle)style mode:(TGPasscodeEntryControllerMode)mode cancelEnabled:(bool)cancelEnabled allowTouchId:(bool)allowTouchId attemptData:(TGPasscodeEntryAttemptData *)attemptData completion:(void (^)(NSString *))completion
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        _style = style;
        _mode = mode;
        _completion = [completion copy];
        _allowTouchId = allowTouchId;
        _cancelEnabled = cancelEnabled;
        _keepStatusBarStyle = true;
        _attemptData = attemptData;
        
        switch (_mode)
        {
            case TGPasscodeEntryControllerModeVerifySimple:
            case TGPasscodeEntryControllerModeVerifyComplex:
            {
                break;
            }
            case TGPasscodeEntryControllerModeSetupSimple:
            case TGPasscodeEntryControllerModeSetupComplex:
            {
                _submode = TGPasscodeEntryControllerSubmodeEnteringNew;
                
                break;
            }
            case TGPasscodeEntryControllerModeChangeSimpleToSimple:
            case TGPasscodeEntryControllerModeChangeSimpleToComplex:
            case TGPasscodeEntryControllerModeChangeComplexToSimple:
            case TGPasscodeEntryControllerModeChangeComplexToComplex:
            {
                _submode = TGPasscodeEntryControllerSubmodeEnteringCurrent;
                
                break;
            }
        }
        
        self.navigationBarShouldBeHidden = true;
        
        if ([self invalidPasscodeAttempts] >= 6 && ![self shouldWaitBeforeAttempting])
        {
            [self resetInvalidPasscodeAttempts];
        }
        
        [self resetMode:_mode];
        
        _shouldWaitTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(checkShouldWait) interval:1.0 repeat:true];
    }
    return self;
}

- (void)dealloc
{
    [_shouldWaitTimer invalidate];
    _shouldWaitTimer = nil;
}

- (void)cancelPressed
{
    if (_completion)
        _completion(nil);
    
    [_view resignFirstResponder];
}

- (void)nextPressed
{
    [self passcodeEntered:[_view passcode]];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return _keepStatusBarStyle ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
}

- (TGPasswordEntryViewStyle)_passwordEntryViewStyleForStyle:(TGPasscodeEntryControllerStyle)style
{
    switch (style)
    {
        case TGPasscodeEntryControllerStyleDefault:
            return TGPasswordEntryViewStyleDefault;
        case TGPasscodeEntryControllerStyleTranslucent:
            return TGPasswordEntryViewStyleTranslucent;
    }
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    CGSize screenSize = self.view.frame.size;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
    {
        screenSize = [UIScreen mainScreen].bounds.size;
        if (screenSize.width > screenSize.height)
        {
            CGFloat tmp = screenSize.width;
            screenSize.width = screenSize.height;
            screenSize.height = tmp;
        }
    }
    
    _view = [[TGPasswordEntryView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, screenSize.width, screenSize.height) style:[self _passwordEntryViewStyleForStyle:_style]];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        _view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    __weak TGPasscodeEntryController *weakSelf = self;
    if (_cancelEnabled)
    {
        _view.cancel = ^
        {
            __strong TGPasscodeEntryController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf cancelPressed];
        };
    }
    _view.simplePasscodeEntered = ^
    {
        __strong TGPasscodeEntryController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf passcodeEntered:[strongSelf->_view passcode]];
    };
    _view.complexPasscodeEntered = ^
    {
        __strong TGPasscodeEntryController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf passcodeEntered:[strongSelf->_view passcode]];
    };
    _view.passcodeChanged = ^(NSString *passcode)
    {
        __strong TGPasscodeEntryController *strongSelf = weakSelf;
        if (strongSelf != nil)
            strongSelf->_nextItem.enabled = passcode.length != 0;
    };
    [self.view addSubview:_view];
    
    [self resetMode:_mode];
    
    [_view becomeFirstResponder];
}

- (bool)supportsTouchId
{
    if (iosMajorVersion() >= 8)
    {
        if ([[[LAContext alloc] init] canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil])
            return true;
    }
    
    return false;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    /*if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        UIView *snapshotView = [_view snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = _view.frame;
        [self.view addSubview:snapshotView];
        [UIView animateWithDuration:duration animations:^
        {
            snapshotView.alpha = 0.0f;
            snapshotView.frame = (CGRect){CGPointZero, [self referenceViewSizeForOrientation:toInterfaceOrientation]};
        } completion:^(__unused BOOL finished)
        {
            [snapshotView removeFromSuperview];
        }];
    }*/
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)prepareForAppear
{
    [_view updateBackgroundIfNeeded];
    
    _keepStatusBarStyle = true;
    if (iosMajorVersion() >= 7)
        [self setNeedsStatusBarAppearanceUpdate];
    
    [_view becomeFirstResponder];
}

- (void)prepareForDisappear
{
    _keepStatusBarStyle = false;
    if (iosMajorVersion() >= 7)
        [self setNeedsStatusBarAppearanceUpdate];
}

- (void)refreshTouchId
{
    [_view resignFirstResponder];
    [_view becomeFirstResponder];
    
    if (!_usingTouchId && !_alternativeMethodSelected && _allowTouchId && [self supportsTouchId] && _touchIdCompletion)
    {
        LAContext *context = [[LAContext alloc] init];
        
        NSError *error = nil;
        if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error])
        {
            _usingTouchId = true;
            [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:TGLocalized(@"EnterPasscode.TouchId") reply:^(BOOL success, NSError *error)
            {
                if (error != nil)
                {
                    TGDispatchOnMainThread(^
                    {
                        _usingTouchId = false;
                        _alternativeMethodSelected = true;
                    });
                }
                else
                {
                    if (success)
                    {
                        TGDispatchOnMainThread(^
                        {
                            _usingTouchId = false;
                            if (_touchIdCompletion)
                                _touchIdCompletion();
                        });
                    }
                    else
                    {
                        TGDispatchOnMainThread(^
                        {
                            _usingTouchId = false;
                        });
                    }
                }
            }];
        }
    }
}

- (NSInteger)invalidPasscodeAttempts {
    return _attemptData.numberOfInvalidAttempts;
}

- (void)addInvalidPasscodeAttempt {
    if (_attemptData == nil) {
        _attemptData = [[TGPasscodeEntryAttemptData alloc] initWithNumberOfInvalidAttempts:1 dateOfLastInvalidAttempt:CFAbsoluteTimeGetCurrent()];
    } else {
        _attemptData = [[TGPasscodeEntryAttemptData alloc] initWithNumberOfInvalidAttempts:_attemptData.numberOfInvalidAttempts + 1 dateOfLastInvalidAttempt:CFAbsoluteTimeGetCurrent()];
    }
    if (_updateAttemptData) {
        _updateAttemptData(_attemptData);
    }
}

- (void)resetInvalidPasscodeAttempts {
    _attemptData = nil;
    if (_updateAttemptData) {
        _updateAttemptData(_attemptData);
    }
}

- (bool)shouldWaitBeforeAttempting
{
    if (_attemptData == nil || [self invalidPasscodeAttempts] < 6)
        return false;
    
    NSTimeInterval invalidAttemptDate = _attemptData.dateOfLastInvalidAttempt;
    NSTimeInterval waitInterval = 60.0;
    
#ifdef DEBUG
    waitInterval = 5.0;
#endif
    
    return CFAbsoluteTimeGetCurrent() - invalidAttemptDate < waitInterval;
}

- (NSTimeInterval)intervalSinceLastInvalidPasscodeAttempt
{
    if (_attemptData == nil) {
        return 9999999.0;
    } else {
        return CFAbsoluteTimeGetCurrent() - _attemptData.dateOfLastInvalidAttempt;
    }
}

- (void)checkShouldWait
{
    if ([self invalidPasscodeAttempts] >= 6 && ![self shouldWaitBeforeAttempting])
    {
        [self resetInvalidPasscodeAttempts];
    }
    [_view setErrorTitle:[self currentErrorText]];
}

- (NSString *)currentErrorText
{
    NSInteger attemptCount = [self invalidPasscodeAttempts];
    if (attemptCount == 0)
        return @"";
    else if (attemptCount < 6)
    {
        NSString *format = [TGStringUtils integerValueFormat:@"PasscodeSettings.FailedAttempts_" value:attemptCount];
        return [[NSString alloc] initWithFormat:TGLocalized(format), [[NSString alloc] initWithFormat:@"%d",(int)attemptCount]];
    }
    else
        return TGLocalized(@"PasscodeSettings.TryAgainIn1Minute");
}

- (void)resetMode:(TGPasscodeEntryControllerMode)mode
{
    _candidatePasscode = nil;
    _mode = mode;
    
    switch (_mode)
    {
        case TGPasscodeEntryControllerModeVerifySimple:
        case TGPasscodeEntryControllerModeVerifyComplex:
        {
            [_view setTitle:TGLocalized(@"EnterPasscode.EnterPasscode") errorTitle:[self currentErrorText] isComplex:_mode == TGPasscodeEntryControllerModeVerifyComplex animated:false];
            
            if (_mode == TGPasscodeEntryControllerModeVerifySimple)
            {
                if (_cancelEnabled)
                {
                    [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelPressed)]];
                }
            }
            else if (_mode == TGPasscodeEntryControllerModeVerifyComplex)
            {
                if (_cancelEnabled)
                {
                    [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelPressed)]];
                }
                _nextItem = [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Next") style:UIBarButtonItemStyleDone target:self action:@selector(nextPressed)];
                [self setRightBarButtonItem:_nextItem];
                _nextItem.enabled = false;
            }
            break;
        }
        case TGPasscodeEntryControllerModeSetupSimple:
        case TGPasscodeEntryControllerModeSetupComplex:
        {
            [_view setTitle:TGLocalized(@"EnterPasscode.EnterNewPasscodeNew") errorTitle:[self currentErrorText] isComplex:_mode == TGPasscodeEntryControllerModeSetupComplex animated:false];
            
            [self setLeftBarButtonItem:nil];
            [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelPressed)]];
            break;
        }
        case TGPasscodeEntryControllerModeChangeComplexToSimple:
        case TGPasscodeEntryControllerModeChangeComplexToComplex:
        case TGPasscodeEntryControllerModeChangeSimpleToSimple:
        case TGPasscodeEntryControllerModeChangeSimpleToComplex:
        {
            bool isComplex = _mode == TGPasscodeEntryControllerModeChangeComplexToSimple || _mode == TGPasscodeEntryControllerModeChangeComplexToComplex;
            [_view setTitle:TGLocalized(@"EnterPasscode.EnterCurrentPasscode") errorTitle:[self currentErrorText] isComplex:isComplex animated:false];
            
            if (_mode == TGPasscodeEntryControllerModeChangeSimpleToSimple)
            {
                [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelPressed)]];
            }
            else
            {
                [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelPressed)]];
            }
            
            _nextItem = [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Next") style:UIBarButtonItemStyleDone target:self action:@selector(nextPressed)];
            if (_mode == TGPasscodeEntryControllerModeChangeComplexToSimple || _mode == TGPasscodeEntryControllerModeChangeComplexToComplex)
            {
                [self setRightBarButtonItem:_nextItem];
            }
            _nextItem.enabled = false;
            
            break;
        }
    }
    
    [_view becomeFirstResponder];
}

- (void)passcodeEntered:(NSString *)passcode
{
    if ([self shouldWaitBeforeAttempting])
    {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        [_view resetPasscode];
        return;
    }
    else if ([self invalidPasscodeAttempts] >= 6)
    {
        [self resetInvalidPasscodeAttempts];
    }
    
    switch (_mode)
    {
        case TGPasscodeEntryControllerModeVerifySimple:
        case TGPasscodeEntryControllerModeVerifyComplex:
        {
            _alternativeMethodSelected = false;
            
            if (_checkCurrentPasscode)
            {
                if (_checkCurrentPasscode(passcode))
                {
                    [self resetInvalidPasscodeAttempts];
                    
                    if (_completion)
                        _completion(passcode);
                }
                else
                {
                    [self addInvalidPasscodeAttempt];
                    
                    [_view setTitle:TGLocalized(@"EnterPasscode.EnterPasscode") errorTitle:[self currentErrorText] isComplex:_mode == TGPasscodeEntryControllerModeVerifyComplex animated:false];
                    
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                }
            }
            else
            {
                if (_completion)
                    _completion(passcode);
            }
            
            break;
        }
        case TGPasscodeEntryControllerModeSetupSimple:
        case TGPasscodeEntryControllerModeSetupComplex:
        {
            switch (_submode)
            {
                case TGPasscodeEntryControllerSubmodeEnteringNew:
                {
                    _candidatePasscode = passcode;
                    _submode = TGPasscodeEntryControllerSubmodeReenteringNew;
                    [_view setTitle:TGLocalized(@"EnterPasscode.RepeatNewPasscode") errorTitle:[self currentErrorText] isComplex:_mode == TGPasscodeEntryControllerModeSetupComplex animated:true];
                    break;
                }
                case TGPasscodeEntryControllerSubmodeReenteringNew:
                {
                    if ([passcode isEqualToString:_candidatePasscode])
                    {
                        if (_completion)
                            _completion(passcode);
                    }
                    else
                    {
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                        _candidatePasscode = nil;
                        _submode = TGPasscodeEntryControllerSubmodeEnteringNew;
                        [_view setTitle:TGLocalized(@"EnterPasscode.EnterNewPasscodeNew") errorTitle:[self currentErrorText] isComplex:_mode == TGPasscodeEntryControllerModeSetupComplex animated:true];
                    }
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case TGPasscodeEntryControllerModeChangeSimpleToSimple:
        case TGPasscodeEntryControllerModeChangeSimpleToComplex:
        case TGPasscodeEntryControllerModeChangeComplexToSimple:
        case TGPasscodeEntryControllerModeChangeComplexToComplex:
        {
            switch (_submode)
            {
                case TGPasscodeEntryControllerSubmodeEnteringCurrent:
                {
                    if (_checkCurrentPasscode && _checkCurrentPasscode(passcode))
                    {
                        [self resetInvalidPasscodeAttempts];
                        
                        _candidatePasscode = nil;
                        _submode = TGPasscodeEntryControllerSubmodeEnteringNew;
                        [_view setTitle:TGLocalized(@"EnterPasscode.EnterNewPasscodeChange") errorTitle:[self currentErrorText] isComplex:_mode == TGPasscodeEntryControllerModeChangeSimpleToComplex || _mode == TGPasscodeEntryControllerModeChangeComplexToComplex animated:true];
                        
                        if (_mode == TGPasscodeEntryControllerModeChangeSimpleToComplex || _mode == TGPasscodeEntryControllerModeChangeComplexToComplex)
                            [self setRightBarButtonItem:_nextItem];
                        else
                            [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelPressed)]];
                    }
                    else
                    {
                        [self addInvalidPasscodeAttempt];
                        
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                        _candidatePasscode = nil;
                        _submode = TGPasscodeEntryControllerSubmodeEnteringCurrent;
                        [_view setTitle:TGLocalized(@"EnterPasscode.EnterCurrentPasscode") errorTitle:[self currentErrorText] isComplex:_mode == TGPasscodeEntryControllerModeChangeComplexToSimple || _mode == TGPasscodeEntryControllerModeChangeComplexToComplex animated:true];
                    }
                    break;
                }
                case TGPasscodeEntryControllerSubmodeEnteringNew:
                {
                    _candidatePasscode = passcode;
                    _submode = TGPasscodeEntryControllerSubmodeReenteringNew;
                    [_view setTitle:TGLocalized(@"EnterPasscode.RepeatNewPasscode") errorTitle:[self currentErrorText] isComplex:_mode == TGPasscodeEntryControllerModeChangeSimpleToComplex || _mode == TGPasscodeEntryControllerModeChangeComplexToComplex animated:true];
                    break;
                }
                case TGPasscodeEntryControllerSubmodeReenteringNew:
                {
                    if ([_candidatePasscode isEqualToString:passcode])
                    {
                        if (_completion)
                            _completion(passcode);
                    }
                    else
                    {
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                        _candidatePasscode = nil;
                        _submode = TGPasscodeEntryControllerSubmodeEnteringNew;
                        [_view setTitle:TGLocalized(@"EnterPasscode.EnterNewPasscodeChange") errorTitle:[self currentErrorText] isComplex:_mode == TGPasscodeEntryControllerModeChangeSimpleToComplex || _mode == TGPasscodeEntryControllerModeChangeComplexToComplex animated:true];
                    }
                    break;
                }
            }
            
            break;
        }
    }
}

@end
