@import Foundation;

@class IDBlockTextView;

NS_ASSUME_NONNULL_BEGIN

@interface IDSelectionCallbackReductionProbe : NSObject

- (instancetype)initWithEditor:(IDBlockTextView *)editor
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (NSDictionary<NSString *, id> *)snapshot;
- (NSString *)serializedSnapshot;

@end

NS_ASSUME_NONNULL_END
