#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDCanonicalTextStorageAdapter.h"
#import "IDBlockDocumentInternal.h"


NS_ASSUME_NONNULL_BEGIN

@interface IDCanonicalTextStorageAdapter (
    IDCanonicalTextStorageAdapterInternal)

@property(nonatomic, copy, nullable) void (^documentChangeHandler)(
    IDBlockDocumentChange *change);

- (nullable IDBlockDocumentChange *)
    id_transformTextAttributesInCanonicalRange:(NSRange)range
                                    usingBlock:
                                        (IDBlockDocumentAttributeTransform)
                                            transform;
- (nullable IDBlockDocumentChange *)id_restoreAttributedBlocks:
    (NSArray<NSAttributedString *> *)blocks;
/// One attribute-only storage edit replacing the blocks' attributed texts (same characters), whose
/// change reports `changedRange` — see `IDBlockDocument`'s method of the same name.
- (nullable IDBlockDocumentChange *)id_restoreAttributedBlocks:
    (NSArray<NSAttributedString *> *)blocks
                                                  changedRange:(NSRange)changedRange;

@end

NS_ASSUME_NONNULL_END

#endif
