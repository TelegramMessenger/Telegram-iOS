// AUTHORED telegram-ios-side — NOT part of the vendored snapshot. See Vendor/VENDOR.md.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGRichTextInputDecRange.h"

@interface TGRichTextInputDecRange ()
@property(nonatomic, strong, readonly) TGRichTextInputDecPosition *startPosition;
@property(nonatomic, strong, readonly) TGRichTextInputDecPosition *endPosition;
// Private designated initializer (mirrors `TGRichTextInputDecPosition`'s own
// `initWithOffset:affinity:revision:`): the public `-init` is `NS_UNAVAILABLE` on this class,
// but that marks only OUR override unavailable to callers — it does not remove `[super init]`,
// which this initializer still calls, so the object gets a genuinely initialized `UITextRange`
// rather than a bare, uninitialized `+alloc`.
- (instancetype)initPrivateFrom:(TGRichTextInputDecPosition *)start
                              to:(TGRichTextInputDecPosition *)end;
@end

@implementation TGRichTextInputDecRange

+ (instancetype)rangeFrom:(TGRichTextInputDecPosition *)start to:(TGRichTextInputDecPosition *)end {
    return [[self alloc] initPrivateFrom:start to:end];
}

- (instancetype)initPrivateFrom:(TGRichTextInputDecPosition *)start
                              to:(TGRichTextInputDecPosition *)end {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _startPosition = start;
    _endPosition = end;
    return self;
}

- (UITextPosition *)start {
    return self.startPosition;
}

- (UITextPosition *)end {
    return self.endPosition;
}

// `UITextRange.isEmpty` compares the two endpoints' OFFSETS — a zero-length range with mismatched
// affinity (e.g. from `emptyTextRangeAtPosition:`, which reuses one resolved position for both
// ends) is still empty; affinity is not part of the length notion at all.
- (BOOL)isEmpty {
    return self.startPosition.utf16Offset == self.endPosition.utf16Offset;
}

// Task R8 (cluster 3) — delegates to `TGRichTextInputDecPosition.isEqual:`, which already compares
// `(utf16Offset, affinity)` only (never `documentRevision` — see that class's own doc comment: two
// positions minted at the same offset/affinity across an unrelated edit must still compare equal).
// Before this fix `TGRichTextInputDecRange` had NO `isEqual:` override at all, so it fell back to
// `NSObject`'s default POINTER-IDENTITY comparison — two ranges built from byte-identical
// offset/affinity/revision values (e.g. `selectedTextRange`'s getter vs a fresh
// `textRange(from:to:)` call over the same position) never compared equal merely because they were
// two distinct objects. That silently defeated the position class's own "value equality" design at
// the one level (`UITextRange`) every `UITextInput` witness this backend exposes actually returns.
- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[TGRichTextInputDecRange class]]) {
        return NO;
    }
    TGRichTextInputDecRange *other = (TGRichTextInputDecRange *)object;
    return [self.startPosition isEqual:other.startPosition] && [self.endPosition isEqual:other.endPosition];
}

- (NSUInteger)hash {
    return self.startPosition.hash ^ (self.endPosition.hash * 31);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p start=%@ end=%@>",
            NSStringFromClass(self.class), self, self.startPosition, self.endPosition];
}

@end

#endif
