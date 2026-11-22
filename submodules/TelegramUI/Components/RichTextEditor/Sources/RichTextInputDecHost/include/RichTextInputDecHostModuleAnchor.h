// telegram-ios-authored, not part of the ported engine.
//
// Deliberately NOT wrapped in `#if TARGET_OS_IOS`. Every other file in this target is
// (TGIDObservingBlockTextView.m subclasses IDBlockTextView, which only exists on iOS), so on
// macOS this module would otherwise compile to nothing at all: an empty translation unit and a
// module a Swift `import` can still name but that carries no symbol. The two siblings this
// target itself depends on solve the same problem the same way
// (Sources/RichTextInputDecObjC/Host/TGRichTextInputDecModuleAnchor.m and
// Sources/RichTextInputDecUpstream/TextView/RichTextInputDecUpstreamModuleAnchor.m); this
// mirrors them.
#import <Foundation/Foundation.h>

/// Its only job is to be a real symbol on every platform.
FOUNDATION_EXPORT void RichTextInputDecHostModuleAnchor(void);
