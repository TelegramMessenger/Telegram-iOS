// telegram-ios-authored. NOT part of the upstream InputDec port — see PROVENANCE.md.
//
// Deliberately NOT wrapped in `#if TARGET_OS_IOS`. Every one of the 78 ported files is,
// so on macOS this module would otherwise compile to nothing at all: eleven-odd empty
// translation units, no Objective-C classes, and a module a Swift `import` can still
// name but that carries no symbol. The vendored sibling module solves the same problem
// the same way with Host/TGRichTextInputDecModuleAnchor.m; this mirrors it.
#import <Foundation/Foundation.h>

/// Returns the number of files brought across from upstream InputDec in phase 1.
/// Its only job is to be a real symbol on every platform.
FOUNDATION_EXPORT NSInteger TGRichTextInputDecUpstreamPortedFileCount(void);
