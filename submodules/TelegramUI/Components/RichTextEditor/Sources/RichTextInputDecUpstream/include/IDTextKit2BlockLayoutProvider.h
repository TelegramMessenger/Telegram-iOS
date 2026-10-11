#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockLayoutSnapshot.h"

@class IDBlockLayout;

NS_ASSUME_NONNULL_BEGIN

@interface IDTextKit2BlockLayoutProvider : NSObject <IDBlockLayoutProvider>

- (instancetype)initWithBlockLayout:(IDBlockLayout *)blockLayout
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

#endif
