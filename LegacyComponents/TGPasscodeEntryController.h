#import <LegacyComponents/TGViewController.h>

typedef enum {
    TGPasscodeEntryControllerModeVerifySimple,
    TGPasscodeEntryControllerModeVerifyComplex,
    TGPasscodeEntryControllerModeSetupSimple,
    TGPasscodeEntryControllerModeSetupComplex,
    TGPasscodeEntryControllerModeChangeSimpleToComplex,
    TGPasscodeEntryControllerModeChangeSimpleToSimple,
    TGPasscodeEntryControllerModeChangeComplexToSimple,
    TGPasscodeEntryControllerModeChangeComplexToComplex
} TGPasscodeEntryControllerMode;

typedef enum {
    TGPasscodeEntryControllerStyleDefault,
    TGPasscodeEntryControllerStyleTranslucent
} TGPasscodeEntryControllerStyle;

@interface TGPasscodeEntryController : TGViewController

@property (nonatomic, copy) void (^completion)(NSString *);
@property (nonatomic, copy) void (^touchIdCompletion)();
@property (nonatomic, copy) bool (^checkCurrentPasscode)(NSString *);
@property (nonatomic) bool allowTouchId;

- (instancetype)initWithStyle:(TGPasscodeEntryControllerStyle)style mode:(TGPasscodeEntryControllerMode)mode cancelEnabled:(bool)cancelEnabled allowTouchId:(bool)allowTouchId completion:(void (^)(NSString *))completion;
- (void)resetMode:(TGPasscodeEntryControllerMode)mode;
- (void)refreshTouchId;
- (void)resetInvalidPasscodeAttempts;
- (void)addInvalidPasscodeAttempt;

- (void)prepareForAppear;
- (void)prepareForDisappear;

@end
