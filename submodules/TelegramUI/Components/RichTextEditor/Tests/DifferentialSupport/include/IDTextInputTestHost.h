#import "IDTextInputScenario.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const IDTextInputTestHostErrorDomain;

@interface IDTextInputTestHost : NSObject

@property(nonatomic, readonly) IDTextInputHostKind kind;
@property(nonatomic, strong, readonly) UIWindow *window;
@property(nonatomic, strong, readonly) UIView<UITextInput> *input;
@property(nonatomic, strong, readonly) NSTextStorage *observedTextStorage;
@property(nonatomic, readonly) BOOL comparesAnnotations;

+ (nullable instancetype)hostWithKind:(IDTextInputHostKind)kind
                             scenario:(IDTextInputScenario *)scenario
                                error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
