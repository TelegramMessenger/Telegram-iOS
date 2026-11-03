#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

@class IDBlockDocument;

NS_ASSUME_NONNULL_BEGIN

/// Canonical temporary attributes backed by live document anchors. Attributes
/// are never written into the document or its derived text storages.
@interface IDRichTextAnnotationStore : NSObject

@property(nonatomic, strong, readonly) IDBlockDocument *document;

- (instancetype)initWithDocument:(IDBlockDocument *)document NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (void)addAttribute:(id<NSCopying>)attribute
                value:(id)value
       canonicalRange:(NSRange)range;
- (nullable id)annotationAttribute:(id<NSCopying>)attribute
                 atCanonicalOffset:(NSUInteger)offset;
- (void)removeAttribute:(id<NSCopying>)attribute
          canonicalRange:(NSRange)range;
- (NSAttributedString *)annotatedSubstringForCanonicalRange:(NSRange)range;

@end

NS_ASSUME_NONNULL_END

#endif
