#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

@class IDBlockDocument;
@class IDCanonicalTextProjection;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IDRichTextAnchorBias) {
    IDRichTextAnchorBiasBefore,
    IDRichTextAnchorBiasAfter,
};

@interface IDRichTextAnchor : NSObject
@property(nonatomic, weak, readonly) IDBlockDocument *document;
@property(nonatomic, copy, readonly) NSUUID *blockIdentifier;
@property(nonatomic, readonly) NSUInteger localOffset;
@property(nonatomic, readonly) IDRichTextAnchorBias bias;

- (instancetype)initWithDocument:(IDBlockDocument *)document
                  blockIdentifier:(NSUUID *)blockIdentifier
                       localOffset:(NSUInteger)localOffset
                              bias:(IDRichTextAnchorBias)bias;
- (NSUInteger)canonicalOffsetInProjection:(IDCanonicalTextProjection *)projection;
@end

NS_ASSUME_NONNULL_END

#endif
