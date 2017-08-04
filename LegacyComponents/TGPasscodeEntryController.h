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

@interface TGPasscodeEntryAttemptData : NSObject

@property (nonatomic, readonly) NSInteger numberOfInvalidAttempts;
@property (nonatomic, readonly) double dateOfLastInvalidAttempt;

- (instancetype)initWithNumberOfInvalidAttempts:(NSInteger)numberOfInvalidAttempts dateOfLastInvalidAttempt:(double)dateOfLastInvalidAttempt;

@end

@interface TGPasscodeEntryController : TGViewController

@property (nonatomic, copy) void (^completion)(NSString *);
@property (nonatomic, copy) void (^touchIdCompletion)();
@property (nonatomic, copy) bool (^checkCurrentPasscode)(NSString *);
@property (nonatomic, copy) void (^updateAttemptData)(TGPasscodeEntryAttemptData *);
@property (nonatomic) bool allowTouchId;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context style:(TGPasscodeEntryControllerStyle)style mode:(TGPasscodeEntryControllerMode)mode cancelEnabled:(bool)cancelEnabled allowTouchId:(bool)allowTouchId attemptData:(TGPasscodeEntryAttemptData *)attemptData completion:(void (^)(NSString *))completion;
- (void)resetMode:(TGPasscodeEntryControllerMode)mode;
- (void)refreshTouchId;

- (NSInteger)invalidPasscodeAttempts;

- (void)prepareForAppear;
- (void)prepareForDisappear;

@end
