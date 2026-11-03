#import "IDTextInputScenario.h"
#import "IDTextInputStateRecorder.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const IDTextInputTransactionErrorDomain;

@interface IDTextInputTransactionDriver : NSObject

- (instancetype)initWithHost:(IDTextInputTestHost *)host
                     recorder:(IDTextInputStateRecorder *)recorder;
- (nullable IDTextInputSnapshot *)
    applyTransaction:(IDTextInputTransaction *)transaction
               index:(NSUInteger)index
               error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
