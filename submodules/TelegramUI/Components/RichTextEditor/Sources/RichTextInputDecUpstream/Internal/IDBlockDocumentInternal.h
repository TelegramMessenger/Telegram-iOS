#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockDocument.h"

NS_ASSUME_NONNULL_BEGIN

@protocol IDBlockDocumentMutationObserver <NSObject>
- (void)id_blockDocumentDidCompleteMutation:(IDBlockDocument *)document;
@end

typedef NSDictionary<NSAttributedStringKey, id> * _Nonnull
    (^IDBlockDocumentAttributeTransform)(
        NSDictionary<NSAttributedStringKey, id> *attributes);

@interface IDBlockDocument (IDBlockDocumentInternal)
- (nullable IDBlockDocumentChange *)id_setDefaultAttributes:
    (NSDictionary<NSAttributedStringKey, id> *)attributes;
- (IDBlockDocumentChange *)id_setAttributes:(
    NSDictionary<NSAttributedStringKey, id> *)attributes
                              canonicalRange:(NSRange)range;
/// Adopts the ATTRIBUTES of `canonical`, the whole document's canonical string with its text
/// unchanged, as one attribute-only change reporting `range`. What `id_setAttributes:canonicalRange:`
/// does after its one `setAttributes:`, for a caller that applied several to one copy — the
/// storage adapter's attribute fixing, which otherwise rebuilt every block once per paragraph.
- (IDBlockDocumentChange *)id_adoptCanonicalAttributes:(NSAttributedString *)canonical
                                          changedRange:(NSRange)range;
- (nullable IDBlockDocumentChange *)
    id_transformTextAttributesInCanonicalRange:(NSRange)range
                                    usingBlock:
                                        (IDBlockDocumentAttributeTransform)
                                            transform;
- (nullable IDBlockDocumentChange *)id_restoreAttributedBlocks:
    (NSArray<NSAttributedString *> *)blocks;
/// As `id_restoreAttributedBlocks:`, reporting `changedRange` as the change's range instead of the
/// whole document: for a batch of attribute edits whose extent the caller knows.
- (nullable IDBlockDocumentChange *)id_restoreAttributedBlocks:
    (NSArray<NSAttributedString *> *)blocks
                                                  changedRange:(NSRange)changedRange;
- (void)id_addMutationObserver:(id<IDBlockDocumentMutationObserver>)observer;
- (void)id_removeMutationObserver:(id<IDBlockDocumentMutationObserver>)observer;
@end

NS_ASSUME_NONNULL_END

#endif
