// AUTHORED telegram-ios-side — NOT part of the vendored snapshot. See Vendor/VENDOR.md.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGRichTextInputDecPosition.h"

@implementation TGRichTextInputDecPosition

+ (instancetype)positionWithOffset:(NSInteger)offset
                           affinity:(UITextStorageDirection)affinity
                           revision:(uint64_t)revision {
    return [[self alloc] initWithOffset:offset affinity:affinity revision:revision];
}

- (instancetype)initWithOffset:(NSInteger)offset
                       affinity:(UITextStorageDirection)affinity
                       revision:(uint64_t)revision {
    self = [super init];
    if (self == nil) return nil;
    _utf16Offset = offset;
    _affinity = affinity;
    _documentRevision = revision;
    return self;
}

// Identity compares `(utf16Offset, affinity)` ONLY — `documentRevision` is staleness metadata,
// not identity (see the header's doc comment): two positions minted at the same offset/affinity
// across an unrelated edit must still compare equal, or every caller that retains a position
// across a document mutation (e.g. an in-flight selection drag) would silently break equality.
- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[TGRichTextInputDecPosition class]]) {
        return NO;
    }
    TGRichTextInputDecPosition *other = (TGRichTextInputDecPosition *)object;
    return self.utf16Offset == other.utf16Offset && self.affinity == other.affinity;
}

- (NSUInteger)hash {
    return (NSUInteger)self.utf16Offset ^ (NSUInteger)(self.affinity * 31);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p offset=%ld affinity=%ld revision=%llu>",
            NSStringFromClass(self.class), self, (long)self.utf16Offset, (long)self.affinity,
            (unsigned long long)self.documentRevision];
}

@end

#endif
