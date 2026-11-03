#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

#import "IDBlockDocument.h"
#import "IDCanonicalTextProjection.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDCanonicalTextStorageAdapter : NSTextStorage
@property(nonatomic, strong, readonly) IDBlockDocument *document;
@property(nonatomic, strong, readonly) IDCanonicalTextProjection *projection;

- (instancetype)initWithDocument:(IDBlockDocument *)document NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

FOUNDATION_EXPORT IDCanonicalTextStorageAdapter *IDCanonicalTextStorageAdapterCreate(
    IDBlockDocument *document);

NS_ASSUME_NONNULL_END

#endif
