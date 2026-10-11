#import "IDTextInputTestHost.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSArray<NSString *> *
IDNormalizedInlineTraitNames(
    NSDictionary<NSAttributedStringKey, id> *attributes);

FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, id> *> *
IDNormalizedInlineRuns(NSTextStorage *storage);

@interface IDTextInputSnapshot : NSObject

@property(nonatomic, copy, readonly) NSString *phase;
@property(nonatomic, copy, readonly)
    NSDictionary<NSString *, id> *state;

@end

@interface IDTextInputStateRecorder : NSObject

- (instancetype)initWithHost:(IDTextInputTestHost *)host;
- (IDTextInputSnapshot *)capturePhase:(NSString *)phase;
- (void)resetTransactionTraces;
- (void)detach;

@end

NS_ASSUME_NONNULL_END
