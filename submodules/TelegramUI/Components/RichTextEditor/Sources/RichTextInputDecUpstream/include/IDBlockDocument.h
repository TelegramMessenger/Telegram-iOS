#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IDBlock : NSObject
@property(nonatomic, copy, readonly) NSUUID *identifier;
@property(nonatomic, copy, readonly) NSAttributedString *attributedText;
@property(nonatomic, copy, readonly) NSDictionary<NSAttributedStringKey, id> *separatorAttributes;
@end

@interface IDBlockDocumentChange : NSObject
@property(nonatomic, readonly) NSRange replacedCanonicalRange;
@property(nonatomic, readonly) NSUInteger replacementLength;
@property(nonatomic, copy, readonly) NSArray<NSUUID *> *affectedBlockIdentifiers;
/// NO for a change that only re-attributed text (`id_setAttributes:`, an attribute transform, a
/// formatting-snapshot restore, a default-attributes change): the characters in
/// `replacedCanonicalRange` are the same before and after. A same-length character replacement
/// (autocorrect `teh` → `the`) has the same range shape, so the range alone cannot tell the two
/// apart; a host that groups TEXT edits (undo coalescing) needs to.
@property(nonatomic, readonly) BOOL charactersChanged;
@end

@interface IDBlockDocument : NSObject
@property(nonatomic, copy, readonly) NSArray<IDBlock *> *blocks;
@property(nonatomic, readonly) NSUInteger canonicalLength;
@property(nonatomic, readonly) NSUInteger documentRevision;
@property(nonatomic, copy, readonly) NSDictionary<NSAttributedStringKey, id> *defaultAttributes;

- (instancetype)initWithAttributedBlocks:(NSArray<NSAttributedString *> *)blocks
                        defaultAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes;
- (IDBlockDocumentChange *)replaceCanonicalRange:(NSRange)range
                            withAttributedString:(NSAttributedString *)replacement;
- (void)setAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
        canonicalRange:(NSRange)range;
@end

NS_ASSUME_NONNULL_END

#endif
