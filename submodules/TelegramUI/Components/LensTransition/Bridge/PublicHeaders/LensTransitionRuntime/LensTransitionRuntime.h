#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(26.0))
@interface LTTransitionDriver : NSObject
+ (BOOL)isSupported;
+ (nullable id)visibilityAssertionForView:(UIView *)view;
- (nullable instancetype)initWithSource:(UITargetedPreview *)source destination:(UITargetedPreview *)destination pivot:(UITargetedPreview *)pivot container:(UIView *)container sourceIdentity:(nullable UIView *)sourceIdentity alongside:(nullable void (^)(void))alongside;
- (void)startWithCompletion:(void (^)(void))completion;
@end
NS_ASSUME_NONNULL_END
