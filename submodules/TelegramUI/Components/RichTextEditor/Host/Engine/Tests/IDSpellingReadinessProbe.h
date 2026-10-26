#import <UIKit/UIKit.h>

@class XCTestCase;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IDSpellingReadinessStatus) {
    IDSpellingReadinessStatusReady,
    IDSpellingReadinessStatusInputModeMismatch,
    IDSpellingReadinessStatusContinuousCheckingDisabled,
    IDSpellingReadinessStatusTemporaryAnnotationUnavailable,
    IDSpellingReadinessStatusMarkerRenderingUnavailable,
};

FOUNDATION_EXPORT NSErrorDomain const IDSpellingInputModeLeaseErrorDomain;

typedef NS_ERROR_ENUM(IDSpellingInputModeLeaseErrorDomain,
                      IDSpellingInputModeLeaseErrorCode) {
    IDSpellingInputModeLeaseErrorInputNotReady = 1,
    IDSpellingInputModeLeaseErrorPriorModeUnavailable,
    IDSpellingInputModeLeaseErrorEnglishUSModeUnavailable,
    IDSpellingInputModeLeaseErrorActivationFailed,
    IDSpellingInputModeLeaseErrorActivationTimedOut,
    IDSpellingInputModeLeaseErrorAlreadyLeased,
    IDSpellingInputModeLeaseErrorRestorationFailed,
    IDSpellingInputModeLeaseErrorKeyboardPipelineTimedOut,
};

@protocol IDSpellingInputModeDriving <NSObject>
- (BOOL)isVisibleFirstResponder:(id)input;
- (BOOL)isKeyboardPipelineReadyForInput:(id)input;
- (nullable id)currentInputModeForInput:(id)input;
- (nullable id)currentControllerInputMode;
- (nullable id)englishUSInputMode;
- (nullable NSString *)identifierForMode:(id)mode;
- (NSUInteger)modeChangeGeneration;
- (BOOL)forceInputMode:(id)mode error:(NSError **)error;
- (void)reloadInputViewsForInput:(id)input;
- (nullable NSString *)primaryLanguageForInput:(id)input;
@end

@interface IDSpellingInputModeLease : NSObject

@property(nonatomic, readonly, getter=isActive) BOOL active;
@property(nonatomic, readonly, getter=isInvalidated) BOOL invalidated;

+ (nullable instancetype)leaseForInput:(id)input
                                driver:(id<IDSpellingInputModeDriving>)driver
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError **)error;
- (BOOL)invalidateWithError:(NSError **)error;

- (instancetype)init NS_UNAVAILABLE;

@end

FOUNDATION_EXPORT IDSpellingReadinessStatus
IDClassifySpellingReadiness(BOOL continuousCheckingEnabled,
                            BOOL temporaryAnnotationObserved,
                            NSUInteger markerPixelCount);
FOUNDATION_EXPORT IDSpellingReadinessStatus
IDClassifySpellingReadinessForPrimaryLanguages(
    NSString *currentPrimaryLanguage,
    NSString *inputPrimaryLanguage,
    BOOL continuousCheckingEnabled,
    BOOL temporaryAnnotationObserved,
    NSUInteger markerPixelCount);
FOUNDATION_EXPORT NSString *
IDSpellingReadinessStatusString(IDSpellingReadinessStatus status);

@interface IDSpellingReadinessObservation : NSObject

@property(nonatomic, readonly) IDSpellingReadinessStatus status;
@property(nonatomic, readonly) BOOL continuousCheckingEnabled;
@property(nonatomic, readonly) BOOL temporaryAnnotationObserved;
@property(nonatomic, readonly) NSUInteger markerPixelCount;
@property(nonatomic, readonly) NSTimeInterval elapsedSeconds;
@property(nonatomic, copy, readonly) NSString *currentPrimaryLanguage;
@property(nonatomic, copy, readonly) NSString *inputPrimaryLanguage;
@property(nonatomic, copy, readonly) NSString *word;
@property(nonatomic, readonly) NSRange wordRange;
@property(nonatomic, readonly) CGRect firstRect;
@property(nonatomic, readonly) CGRect markerROI;
@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *dictionaryRepresentation;

- (instancetype)initWithStatus:(IDSpellingReadinessStatus)status
      continuousCheckingEnabled:(BOOL)continuousCheckingEnabled
    temporaryAnnotationObserved:(BOOL)temporaryAnnotationObserved
               markerPixelCount:(NSUInteger)markerPixelCount
                 elapsedSeconds:(NSTimeInterval)elapsedSeconds
         currentPrimaryLanguage:(NSString *)currentPrimaryLanguage
           inputPrimaryLanguage:(NSString *)inputPrimaryLanguage
                           word:(NSString *)word
                      wordRange:(NSRange)wordRange
                      firstRect:(CGRect)firstRect
                      markerROI:(CGRect)markerROI NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

FOUNDATION_EXPORT IDSpellingReadinessObservation *
IDObserveStockSpellingReadiness(UITextView *editor, NSTimeInterval timeout);
FOUNDATION_EXPORT BOOL IDAssertEnglishCheckerAvailable(XCTestCase *testCase);
FOUNDATION_EXPORT void IDAttachSpellingObservation(
    XCTestCase *testCase,
    NSString *role,
    NSDictionary<NSString *, id> *observation,
    UIImage * _Nullable image);

typedef NS_ENUM(NSInteger, IDSpellingLifecycleStimulus) {
    IDSpellingLifecycleStimulusOneShot,
    IDSpellingLifecycleStimulusStaged,
};

@interface IDSpellingLifecycleTrace : NSObject

@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *dictionaryRepresentation;

- (instancetype)init NS_UNAVAILABLE;

@end

FOUNDATION_EXPORT IDSpellingLifecycleTrace *
IDObserveStockSpellingLifecycle(UITextView *editor,
                                IDSpellingLifecycleStimulus stimulus,
                                NSTimeInterval timeout);

NS_ASSUME_NONNULL_END
