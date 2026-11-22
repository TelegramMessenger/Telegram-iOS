@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface IDRichTextLayoutControllerContractProbe : NSProxy
@property(nonatomic, strong, readonly) id target;
@property(nonatomic, copy, readonly) NSArray<NSString *> *recordedSelectors;
- (instancetype)initWithTarget:(id)target;
- (BOOL)recordedSelector:(SEL)selector;
@end

NS_ASSUME_NONNULL_END
