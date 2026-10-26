#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

#import "IDBlockDocument.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IDCanonicalBoundarySide) {
    IDCanonicalBoundarySideText,
    IDCanonicalBoundarySideBeforeSeparator,
    IDCanonicalBoundarySideAfterSeparator,
};

@interface IDCanonicalLocation : NSObject
@property(nonatomic, copy, readonly) NSUUID *blockIdentifier;
@property(nonatomic, readonly) NSUInteger localOffset;
@property(nonatomic, readonly) IDCanonicalBoundarySide boundarySide;
@end

@interface IDCanonicalTextProjection : NSObject
@property(nonatomic, weak, readonly) IDBlockDocument *document;
@property(nonatomic, copy, readonly) NSString *string;
@property(nonatomic, copy, readonly) NSAttributedString *attributedString;

- (instancetype)initWithDocument:(IDBlockDocument *)document;
- (nullable IDCanonicalLocation *)locationForCanonicalOffset:(NSUInteger)offset;
- (NSUInteger)canonicalOffsetForBlockIdentifier:(NSUUID *)identifier
                                     localOffset:(NSUInteger)localOffset;
@end

NS_ASSUME_NONNULL_END

#endif
