#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

@class IDBlockDocument;
@class IDBlockStackCanvasView;
@class IDCanonicalTextStorageAdapter;
@class IDRichTextPosition;
@class IDRichTextRange;

NS_ASSUME_NONNULL_BEGIN

@interface IDRichTextLayoutController : NSObject {
@private
    __strong id _id_textInputControllerConnection;
}

@property(nonatomic, strong, readonly) IDBlockDocument *document;
@property(nonatomic, strong, readonly) IDCanonicalTextStorageAdapter *textStorageAdapter;
@property(nonatomic, strong, nullable, readonly) id inputController;

- (instancetype)initWithDocument:(IDBlockDocument *)document
                       blockStack:(IDBlockStackCanvasView *)blockStack;
- (instancetype)init NS_UNAVAILABLE;
- (IDRichTextPosition *)positionForCanonicalOffset:(NSUInteger)offset
                                          affinity:(UITextStorageDirection)affinity;
- (IDRichTextRange *)rangeForCanonicalRange:(NSRange)range;
- (NSRange)canonicalRangeForTextRange:(IDRichTextRange *)range clipped:(BOOL)clipped;

@end

NS_ASSUME_NONNULL_END

#endif
